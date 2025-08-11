from pyspark.ml.classification import LogisticRegression, RandomForestClassifier
from pyspark.ml.feature import VectorAssembler, StringIndexer, StandardScaler
from pyspark.ml.evaluation import BinaryClassificationEvaluator
from pyspark.ml import Pipeline
from pyspark.sql import SparkSession
from pyspark.sql.functions import udf, col, when, isnan, isnull
from pyspark.sql.types import DoubleType, StringType, IntegerType
import numpy as np

# Initialize Spark
spark = SparkSession.builder \
    .appName("advanced-ml-example") \
    .config("spark.sql.adaptive.enabled", "true") \
    .getOrCreate()

# Load data
df = spark.read.parquet("s3a://data/features.parquet")

# ===== UDF EXAMPLES =====

# 1. Simple mathematical UDF
@udf(returnType=DoubleType())
def calculate_bmi(weight, height):
    """Calculate BMI with null handling"""
    if weight is None or height is None or height == 0:
        return None
    return float(weight) / (float(height) ** 2)

# 2. Complex feature engineering UDF
@udf(returnType=StringType())
def risk_category(age, income, credit_score):
    """Categorize risk based on multiple factors"""
    if any(x is None for x in [age, income, credit_score]):
        return "unknown"
    
    risk_score = 0
    if age < 25 or age > 65:
        risk_score += 1
    if income < 30000:
        risk_score += 2
    if credit_score < 600:
        risk_score += 3
    
    if risk_score >= 4:
        return "high"
    elif risk_score >= 2:
        return "medium"
    else:
        return "low"

# 3. Array processing UDF (using numpy)
@udf(returnType=DoubleType())
def calculate_volatility(price_array):
    """Calculate price volatility from array of prices"""
    if price_array is None or len(price_array) < 2:
        return 0.0
    
    prices = np.array(price_array)
    returns = np.diff(np.log(prices))
    return float(np.std(returns))

# 4. Text processing UDF
@udf(returnType=IntegerType())
def count_special_chars(text):
    """Count special characters in text"""
    if text is None:
        return 0
    return sum(1 for char in text if not char.isalnum() and not char.isspace())

# ===== DATA PREPROCESSING WITH UDFs =====

# Apply UDFs for feature engineering
df_engineered = df \
    .withColumn("bmi", calculate_bmi(col("weight"), col("height"))) \
    .withColumn("risk_category", risk_category(col("age"), col("income"), col("credit_score"))) \
    .withColumn("special_char_count", count_special_chars(col("description"))) \
    .withColumn("price_volatility", calculate_volatility(col("price_history")))

# Handle missing values with UDF
@udf(returnType=DoubleType())
def fill_missing_with_median(value, median_val):
    """Fill missing values with provided median"""
    return median_val if value is None else value

# Calculate median for imputation (collect to driver)
median_income = df_engineered.approxQuantile("income", [0.5], 0.01)[0]

df_clean = df_engineered \
    .withColumn("income_filled", fill_missing_with_median(col("income"), median_income)) \
    .drop("income") \
    .withColumnRenamed("income_filled", "income")

# ===== ML PIPELINE WITH FEATURE ENGINEERING =====

# String indexing for categorical features
risk_indexer = StringIndexer(inputCol="risk_category", outputCol="risk_category_idx")

# Feature assembly
feature_cols = ["f1", "f2", "f3", "bmi", "risk_category_idx", 
                "special_char_count", "price_volatility", "income"]
assembler = VectorAssembler(inputCols=feature_cols, outputCol="raw_features")

# Feature scaling
scaler = StandardScaler(inputCol="raw_features", outputCol="features")

# Multiple models for comparison
lr = LogisticRegression(maxIter=100, regParam=0.01)
rf = RandomForestClassifier(numTrees=50, maxDepth=10)

# Create pipelines
lr_pipeline = Pipeline(stages=[risk_indexer, assembler, scaler, lr])
rf_pipeline = Pipeline(stages=[risk_indexer, assembler, scaler, rf])

# ===== MODEL TRAINING AND EVALUATION =====

# Split data
train, test = df_clean.randomSplit([0.8, 0.2], seed=42)

# Train models
print("Training Logistic Regression...")
lr_model = lr_pipeline.fit(train)

print("Training Random Forest...")
rf_model = rf_pipeline.fit(train)

# Make predictions
lr_pred = lr_model.transform(test)
rf_pred = rf_model.transform(test)

# ===== CUSTOM EVALUATION UDFs =====

@udf(returnType=StringType())
def prediction_confidence(probability):
    """Categorize prediction confidence based on probability"""
    if probability is None:
        return "unknown"
    
    # Extract probability for positive class (assuming binary classification)
    prob_positive = float(probability[1])
    
    if prob_positive > 0.8 or prob_positive < 0.2:
        return "high"
    elif prob_positive > 0.65 or prob_positive < 0.35:
        return "medium"
    else:
        return "low"

@udf(returnType=DoubleType())
def custom_error_metric(prediction, label, weight=1.0):
    """Custom weighted error calculation"""
    if prediction is None or label is None:
        return 0.0
    
    error = abs(float(prediction) - float(label))
    return error * weight

# Apply evaluation UDFs
lr_pred_final = lr_pred \
    .withColumn("confidence", prediction_confidence(col("probability"))) \
    .withColumn("weighted_error", custom_error_metric(col("prediction"), col("label")))

rf_pred_final = rf_pred \
    .withColumn("confidence", prediction_confidence(col("probability"))) \
    .withColumn("weighted_error", custom_error_metric(col("prediction"), col("label")))

# ===== MODEL EVALUATION =====

evaluator = BinaryClassificationEvaluator(labelCol="label", rawPredictionCol="rawPrediction")

lr_auc = evaluator.evaluate(lr_pred)
rf_auc = evaluator.evaluate(rf_pred)

print(f"Logistic Regression AUC: {lr_auc:.4f}")
print(f"Random Forest AUC: {rf_auc:.4f}")

# Show predictions with custom features
print("\nLogistic Regression Predictions:")
lr_pred_final.select("label", "prediction", "probability", "confidence", "weighted_error") \
    .show(10, truncate=False)

print("\nRandom Forest Predictions:")
rf_pred_final.select("label", "prediction", "probability", "confidence", "weighted_error") \
    .show(10, truncate=False)

# ===== FEATURE IMPORTANCE (Random Forest) =====

# Extract feature importance using UDF
@udf(returnType=StringType())
def format_feature_importance(feature_idx, importance_score):
    """Format feature importance for display"""
    feature_names = ["f1", "f2", "f3", "bmi", "risk_category_idx", 
                    "special_char_count", "price_volatility", "income"]
    if feature_idx < len(feature_names):
        return f"{feature_names[feature_idx]}: {importance_score:.4f}"
    return f"feature_{feature_idx}: {importance_score:.4f}"

# Get feature importances
rf_model_final = rf_model.stages[-1]  # Get the RandomForest model
feature_importances = rf_model_final.featureImportances

print("\nFeature Importances (Random Forest):")
for i, importance in enumerate(feature_importances):
    print(f"Feature {i}: {importance:.4f}")

# ===== BATCH PREDICTION UDF =====

@udf(returnType=DoubleType())
def ensemble_prediction(lr_prob, rf_prob, lr_weight=0.4, rf_weight=0.6):
    """Ensemble prediction combining multiple models"""
    if lr_prob is None or rf_prob is None:
        return 0.5
    
    lr_pos_prob = float(lr_prob[1])
    rf_pos_prob = float(rf_prob[1])
    
    ensemble_prob = (lr_pos_prob * lr_weight) + (rf_pos_prob * rf_weight)
    return ensemble_prob

# Create ensemble predictions
ensemble_pred = lr_pred.alias("lr").join(rf_pred.alias("rf"), "features") \
    .withColumn("ensemble_prob", 
                ensemble_prediction(col("lr.probability"), col("rf.probability"))) \
    .withColumn("ensemble_prediction", 
                when(col("ensemble_prob") > 0.5, 1.0).otherwise(0.0))

print("\nEnsemble Predictions:")
ensemble_pred.select("lr.label", "ensemble_prediction", "ensemble_prob").show(10)

# Clean up
spark.stop()