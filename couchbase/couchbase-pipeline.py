# pip install couchbase
# Use anaconda for better environment management!
# needed for environment variables
import os
# import logging
import logging
# couchbase dependencies
from couchbase.cluster import Cluster, ClusterOptions
from couchbase.auth import PasswordAuthenticator
from couchbase.exceptions import CouchbaseException, AuthenticationException, BucketNotFoundException

# Set up logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")

def get_env_var(var_name):
    """
    Retrieve an environment variable and validate its presence.
    :param var_name: Name of the env variable
    :return: The variable's value, otherwise raise an error
    """
    value = os.getenv(var_name)
    if not value:
        raise ValueError(f"Environment variable '{var_name}' is missing.")
    return value

def connect_to_couchbase():
    """
    Establish connection to Couchbase and return default collection.
    :return: Couchbase collection object.
    """
    try:
        # Couchbase Connection Configuration
        COUCHBASE_HOST = get_env_var("COUCHBASE_HOST") # Retrieved from KV Secret
        USERNAME = get_env_var("COUCHBASE_UNAME")
        PASSWORD = get_env_var("COUCHBASE_PASS")
        BUCKET_NAME = get_env_var("CB_BUCKET_NAME")
        
        # Authentication
        auth = PasswordAuthenticator(USERNAME, PASSWORD)
        cluster = Cluster(COUCHBASE_HOST, ClusterOptions(auth))
        
        # Open Bucket
        bucket = cluster.bucket(BUCKET_NAME)
        collection = bucket.default_collection()
        
        logging.info(f"Successfully connected to couchbase bucket '{BUCKET_NAME}'.")
        return collection
        
    except AuthenticationException as auth_error:
        logging.error("Authentication failed. Please check your credentials.")
        raise auth_error
    except BucketNotFoundException as bucket_error:
        logging.error("Bucket not found. Ensure the bucket name is correct.")
        raise bucket_error
    except CouchbaseException as e:
        logging.error(f"Connection Error: {e}")
        raise e

def main():
    """
    Main function to connect to Couchbase and perform an example operation.
    """
    try:
        collection = connect_to_couchbase()
        
        # Example operation: Inserting a test document
        test_key = "sample_doc"
        test_value = {"name": "Test Document", "status": "active"}
        collection.upsert(test_key, test_value)
        
        logging.info(f"Document '{test_key}' inserted successfully!")
        
    except Exception as e:
        logging.error(f"An error occurred: {e}")

# Sets up ability to execute script as ./couchbase-pipeline.py
if __name__ == "__main__":
    main()