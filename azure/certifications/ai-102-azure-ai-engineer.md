# Azure AI Engineer
[Learning Path](https://learn.microsoft.com/en-us/training/courses/ai-102t00)

## Azure AI Services
- **Azure AI Services** are a set of individual services that you can use as building blocks in intelligent applications.

- `Azure AI Agent Service`: Combine gen AI models with tools to allow agents to interact with real data.
- `Azure AI Model Inference`: Performs model inference for flagship models in Azure AI model catalog.
- `Azure AI Search`: AI-powered cloud search to mobile/web apps.
- `Azure OpenAI`: Variety of natural language tasks.
- `Bot Service`: Create bots and connect across channels.
- `Content Safety`: AI service that detects unwanted contents.
- `Document Intelligence`: Turn docs into intelligent data-driven solutions.
- `Face`: detect/identify people and emotions.
- `Immersive Reader`: Help users read/comprehend text.
- `Language`: Build apps with Natural language capabilities.
- `Speech`: Speech-to-text, Text-to-speech, translation, speaker recognition.
- `Translator`: AI-powered translation technology to translate more than 100 languages/dialects.
- `Video Indexer`: Extract actionable insights from your videos.
- `Vision:` Analyze content in images/videos. Can train with tags, positive or negative. Choose probability threshold.

- You can create a `multi-service` (i.e. Language, Vision, Speech) or `single-service` (i.e. discrete Language resource). Multi-service has a single endpoint for all services.
    - You can separate billing and resources for *training* a model vs *prediction*. For example, a generic AI Services resource to make the model available for inferencing


- **Pricing tiers** are based on number of transactions sent using your authentication information.
    - Max number of allowed Transactions per Second (TPS)
    - Service features enabled within the pricing tier
    - Cost for predefned number of transactions, going above incurs an extra charge.

- There are *on-premises containers* that allow you to bring Azure AI services closer to your data for compliance.
- Some services allow you to *bring your own data*, then train a model.
- Ensure the icon for the Azure AI Services resource is the latest (non-cloud icon)

### Identify endpoints and keys
- Applications require the following information to consume AI services:
    - `Endpoint URI`: HTTP address for REST access.
    - `Subscription Key`: Client apps must provide a valid key to consume the service (primary or secondary)
    - `Resource location`: Some require a location.

### Security and Authentication

- You should regenerate keys regularly with `az cognitiveservices account keys regenerate`.
    - Two keys, Key1 and Key2 are provided so you can regenerate keys without service interruption.
    - From the portal, go to the `Keys and Endpoints` blade.

- When using `Token-based authentication`, the subscription key is passed as an initial request. When using an SDK, calls to obtain and present token are handled for you.

- Use **Entra ID** with: `New-AzureADApplication`, `New-AzADServicePrincipal`, `New-AzRoleAssigment -RoleDefinitionName "Cognitive Services User"`

- Assign a User or System assigned MI: `az vm identity assign -g mygroup -n myvm`

- Network configurations: 
    - (Default) All networks
    - Selected Networks and private endpoints
    - Disabled: Most restrictive.

- **Resource Providers** of trusted services which have preconfigured exceptions to network rules for Azure AI Services:
    - Azure AI Services: `Microsoft.CognitiveServices`
    - Azure ML (Foundry): `Microsoft.MachineLearningServices`
    - Azure AI Search: `Microsoft.Search`
- When exceptions are enabled, these trusted services use managed identity to authenticate to your AI service.

### Monitor Azure AI Services

#### Plan and View Costs
- Use the `Azure Pricing Calculator` to estimate costs by selecting Azure AI services in the AI + Machine Learning category. You can export it into excel format.
- View costs by going to `Cost analysis` tab and filtering `service name`.

#### Create alerts
- Go to the `Alerts` tab on the `Monitoring` blade on the left, and create an alert rule:
    - `Scope` of the alert rule
    - `Condition` on which alert is triggered based on a **signal type** like `Activity Log` or `Metric`.
    - Optional `Actions`, like sending an email.
    - `Alert rule details`, like name and resource group.

#### View Metrics
- Go to the `Metrics` tab on the `Monitoring` blade on the left to find total Count calls for the ai resource, you can add multiple metrics.
- Add to a `Dashboard` by searching for it in the portal. You can add up to 100 named dashboards.

#### Manage Diagnostics
- You will usually use one or both of:
    - Azure Log Analytics: query and visualize log data.
    - Storage: store log archives.
- Go to the `Diagnostic settings` page of the blade for your AI service.
    - Enter a `name` for the setting
    - The `categories` of log event to capture. (Trace, RequestResponse, Audit, AllMetrics)
    - Details of `destinations` to store the log data. (Send to LA and archive to storage account)

### Deploy Azure AI Services in Containers

- Deploying Azure AI Services in a container on-prem will decrease latency between service and data, to improve performance.
- Steps to deploy and use an AI services container:
1) Container image for specific AI service API is downloaded and deployed to container host (docker server, ACI, AKS)
2) Client apps submit data to the endpoint provided by containerized service.
3) (Periodically) Usage metrics for containerized service are sent to Azure AI services to calculate billing. **Must provision an AI services resource for billing purposes**

- **Language Service Containers:**

|Feature|Image|
|-------|-----|
|Key Phrase Extraction | `mcr.microsoft.com/azure-cognitive-services/textanalytics/keyphrase` |
|Language Detection | `mcr.microsoft.com/azure-cognitive-services/textanalytics/language` |
|Sentiment Analysis | `mcr.microsoft.com/azure-cognitive-services/textanalytics/sentiment` |
|Named Entity Recognition | `mcr.microsoft.com/product/azure-cognitive-services/textanalytics/language/about` |
|Text Analytics for Health | `mcr.microsoft.com/product/azure-cognitive-services/textanalytics/healthcare/about` |
|Translator | `mcr.microsoft.com/product/azure-cognitive-services/translator/text-translation/about` |
|Summarization | `mcr.microsoft.com/azure-cognitive-services/textanalytics/summarization` |

- **Note**, sentiment analysis supports other languages by replacing `en` in language code.

- **Speech Service Containers:**

|Feature|Image|
|-------|-----|
|Speech to text | `mcr.microsoft.com/product/azure-cognitive-services/speechservices/speech-to-text/about` |
|Custom Speech to text | `mcr.microsoft.com/product/azure-cognitive-services/speechservices/custom-speech-to-text/about` |
|Natural Text to Speech | `mcr.microsoft.com/product/azure-cognitive-services/speechservices/natural-text-to-speech/about` |
|Speech Language detection | `mcr.microsoft.com/product/azure-cognitive-services/speechservices/language-detection/about` |

- **Vision Containers:**

|Feature|Image|
|-------|-----|
|Read OCR | `mcr.microsoft.com/product/azure-cognitive-services/vision/read/about` |
|Spatial analysis | `mcr.microsoft.com/product/azure-cognitive-services/vision/spatial-analysis/about` |

- **Note** some of the images are in a Gated state for public preview and you need to explicitly request access.

- When you deploy a container image to a host, you specify:
    - `ApiKey`: Key from deployed AI service (for billing)
    - `Billing`: Endpoint URI (used for billing)
    - `Eula`: Value of accept for license of container.
- You do not need a subscription for Microsoft, but you can implement your own authentication.


## Azure AI Foundry
- `Azure AI Foundry`, the AI app and agent factory, is focused on model customization, orchestration and grounding. 
- An Azure AI Foundry `project` is where most development work happens. You can use an SDK or work in the portal. Types of project:
1) Foundry project: build on Azure AI Foundry resource. Simple setup, access to agents, and models.
2) Hub based project: hosted by a Foundry `hub` (associated with an Azure AI hub resource) usually created by an administrative team, and you can create a project in that hub. Hub has features NOT available in a Foundry project.

- Left Blade:` Define and explore`. `Build and customize`. `Observe and improve`.
- From the `management center`, you can view:
    - projects and resources
    - quotas and usage metrics
    - govern access and permissions

- For development, you can install VS code in a container image, `Azure AI Foundry VS Code container image`, (hosted in compute) to have the latest versions of the SDK.
    - Important tools include: `Azure AI Foundry SDK`(write code and connect to AI Foundry projects, access resource connections), `Azure AI Services SDKs` (service-specific libraries for multiple programming languages), `Azure AI Foundry Agent Service` (can be integrated with frameworks like AutoGen and Semantic Kernel), `Prompt Flow SDK` (implement orchestration logic)

### Azure AI Foundry Content Safety

- `AI Foundry Content Safety` is a service designed to help devs include advanced content safety in their applications.
- Need for Content Safety:
    - Increase in harmful content: growth of user-generated online/inappropriate content.
    - Regulatory pressures: Government.
    - Transparency: Users need to understand standards and enforcement.
    - Complex Content: Users can post multimodal content and videos.

- Visit `Azure AI Foundry` -> `Content Safety`:
    - `Moderate text content`: scans across violence, hate speech, s content, s-harm. Scored 0-6
    - `Groundedness detection`: response based on source information, includes "reasoning" option.
    - `Protected material detection for text`: checks AI-generated text for copywritten material.
    - `Protected material detection for code`: checks AI-generated text for copywritten material.
    - `Prompt shields`: unified API to block jailbreak attacks from inputs into LLMs (user input and docs)
    - `Moderate image content`: violence, s-harm, s, hate.
    - `Moderate multimodal content`: scans both images and text, including OCR, for violence, hate speech, s content, s-harm.
    - `Custom categories`: create your own categories with positive and negative examples to train.
    - `Safety system message`: helps you write effective prompts to guide behavior.

- You can access `Azure AI Content Studio` from either (a) Azure AI Foundry or (b) Content Safety Studio.

- Evaluating Accuracy: TP, FP, TN, FN.

### Explore AI Foundry Content Catalog
- `Foundational models`, like GPT, are state-of-the-art language models designed to interact with natural language.

- The transformer architecture, developed by Vaswani (Attention is all you need), resulted in two innovations:
1) Trasnsformers process each word independently and in parallel by using `attention`. Instead of sequential processing.
2) Transformers use `positional encoding` to include the info about the position of a word in a sentence, next to the semantic similarity between words.

- The `model catalog` in Foundry is a central repo to find the right language model. All models in the catalog meet standards for Responsible AI.
- Consider these characteristics when choosing:
1) Task type:
2) Precision:
3) Openness:
4) Deployment:

- Use model benchmarks: Accuracy, Coherence, Fluency, Groundedness, GPT Similarity, Quality Index, Cost.

- You can categorize by LLM or SLM:

| Model Size |Examples | Use Case|
|------|------|----|
|**LLM**|`GPT-4`, `Mistral Large`, `Llama3 70B`, `Llama 405B`, `Command R+`| Powerful, designed for deep reasoning, complex content generation, extensiive content understanding. |
|**SLM**|`Phi3m`, `Mistral OSS models`, `Llama3 8B`| Efficient, cost-effective, can handle many common NLP tasks, perfect for running lower-end or edge devices. |

- You can categorize by modality or task:

| Model Type | Examples | Use Case |
|-------|----------|---------|
| Chat completion models |`GPT-4`, `Mistral Large`| generate coherent and contextually appropriate text responses |
| Reasoning models |`DeepSeek-R1`, `o1` | perform complex math, coding, science, logistics, strategy|
| multi-modal models |`GPT-4o`, `Phi3-vision` |process images, audio, other data types, digital tutor app.|
| image generation models |`DALL-E 3`, `Stability AI` | create realistic visuals from text prompts, marketing.|
| embedding models|`Ada`, `Cohere`| convert text into numerical representations to improve search relevance by understanding semantics.|
|regional and domain-specific models|`Core42`, `Nixtla TimeGEN-1`|Arabic LLM, time-series forecasting.|
|Proprietary models|`OpenAI GPT-4`, `Mistral Large`, `Cohere Command R+`| Enterprise level security support and accuracy|
|Open source models| `Hugging Face`, `Meta`, `Databricks`, `Snowflake`, `Nvidia`| Give developers more control for fine-tuning and customization.|


- You can add `function calling` and `JSON support` to be useful for automating database queries, API calls, structured data processing.

- Example Target URI: `https://ai-aihubdevdemo.openai.azure.com/openai/deployments/gpt-35-turbo/chat/completions?api-version=2023-03-15-preview`
    - hub name (ai-aihubdevdemo)
    - model name (gpt-35-turbo)
    - task (chat/completions)

- Apply prompt patterns, known as `prompt engineering`, to optimize your models output, once you have an endpoint. (Instruct model to act as a persona, guide model, provide a template for output, ask for explanation, provide context etc.) Known as a `system message`
- Other optimization strategies: `RAG` (grounding context to prompts), `Fine-tuning` (extending the training of a foundational model).
- You can aim to optimize for context (`maximize response accuracy`) or optimize model (`maximize consistency of behavior`)

### Develop App with AI Foundry SDK

- The `Azure AI Foundry SDK` brings together common services and code libraries in an AI project through a central programmatic access point.

- Installing packages: `pip install azure-ai-projects` or `dotnet add package Azure.AI.Projects --prerelease`
- `Overview` -> `Endpoints and Keys` to find the API key and Library endpoints (Foundry, Azure OpenAI, Azure AI Services)
- Create an AIProjectClient Object to provide a programmatic proxy.
```python
from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
...

project_endpoint = "https://......"
project_client = AIProjectClient(            
    credential=DefaultAzureCredential(),
    endpoint=project_endpoint)
```
- Azure AI Foundry projects contain `connected resources`, which are defined by the `parent` Foundry or hub resource, and at the `project` level. Each resource is a `connection` to an external service.
- The AIProjectClient object has different properties:
- `connections.list()`
- `ConnectionType.AZURE_OPEN_AI` as an optional `connection_type`
- `connections.get(connection_name, include_credentials)`

- Model Hosting Solutions:
    - Azure AI Foundry Models: single endpoint for multiple models.
    - Azure OpenAI: single endpoint for OpenAI models, consumed Azure OpenAI resource connection to project.
    - Serverless API: model-as-a-service solution, unique endpoint hosted in Foundry project.
    - Managed Compute: Model-as-a-service solution, custom unique endpoint.

- **Note**: Select `Deploy models to Azure AI model inference service` in AI Foundry.

- `ChatCompletionsClient` object to chat with phi-4-model:
    - Need `pip install azure-ai-inference` and `pip install openai`

```python
from azure.ai.projects import AIProjectClient
from azure.identity import DefaultAzureCredential
from azure.ai.inference.models import SystemMessage, UserMessage

try:

    # Initialize the project client
    project_client = AIProjectClient(            
        credential=DefaultAzureCredential(),
        endpoint=project_endpoint)

    ## Get a chat client
    chat_client = project_client.inference.get_chat_completions_client()

    # Get a chat completion based on a user-provided prompt
    user_prompt = input("Enter a question:")

    response = chat_client.complete(
        model="phi-4-model",
        messages=[
            SystemMessage("You are a helpful AI assistant that answers questions."),
            UserMessage(user_prompt)
        ],
    )
    print(response.choices[0].message.content)

except Exception as ex:
    print(ex)
```

### Foundry Prompt Flow - Develop Language model apps

- `Prompt flow` takes a prompt as input, and allows you to create flows, which referes to sequence of actions taken afterwards. It is a process or pipeline that incorporates interaction with the LLM.
    - Accessible in AI Foundry and Azure ML Studio.

- **Language App and Flow Lifecycle**:
1) Initialization: Define use case and design solution.
    - Define the objective
    - Collect sample data
    - Build a basic prompt
    - Design the flow
2) Experimentation: Develop flow and test with small dataset.
    - Run flow against sample dataset
    - Evaluate prompts performance.
    - Move on OR modify prompt/flow.
3) Evaluation and Refinement: Assess flow with larger dataset.
    - Asses with larger dataset
    - Evaluate how LLM app generalizes new data.
4) Production: Deploy and monitor the flow and application.
    - Optimize flow for efficiency and effectiveness
    - Deploy flow to an endpoint, and generate the output with a call.
    - Monitor the performance by collecting data and end-user feedback.

- **Prompt Flow core components:** `(1) Inputs` - represents data passed, like strings, integers or bools, `(2) Nodes` - represent tools that process data, algorithmic operations, `(3) Outputs` - data produced by the flow.

- Three common tools: LLM tool, Python tool, Prompt tool.

- Three common flows:
    - Standard flow: Ideal for LLM-based app development.
    - Chat flow: Conversational applications
    - Evaluation flow: Performance evaluation, analysis and improvement.

- A `Connection` is a secure link between the prompt flow and external services. Depending on the connection, stores the endpoint, API Key, or credentials necessary for prompt flow.
- After creating the flow and connections, you need compute aka `runtimes` (Compute instance and an environment)

|Connection Type|Built-in Tools|
|--------------|---------------|
|Azure OpenAI| LLM or Python|
|OpenAI| LLM or Python|
|Azure AI Search| Vector DB Lookup or Python |
|Serp| Serp API or Python|
|Custom|  Python|

- Prompt flow `variants` are versions of a tool node with distinct settings. Benefits to using variants:
    - Enhance quality of LLM generation
    - Save time/effort
    - Boost Productivity
    - Facilitate easy comparison

- When you deploy your flow to an online `endpoint`, prompt flow generates a URL and key so you can safely integrate your flow with other applications or business processes.

- **Key Metrics** for evaluation: `Groundedness`, `Relevance`, `Coherence`, `Fluency`, `Similarity`.

- `@tool` in `promptflow` decorator marks a Python function as a reusable tool wired into prompt flow. Defines a `tool node` you can use in `flow.dag.yaml` and an `inputs.jsonl` (json lines). The `llm_extract.jinja` is a prompt extract which is used in the flow.dag.yaml

```python
from promptflow import tool

@tool
def format_prompt(question: str, context: str) -> str:
    return f"Answer the question using the context.\nContext: {context}\nQuestion: {question}"
```

```yaml
# flow.dag.yaml
id: my_standard_flow
name: my_standard_flow
nodes:
  - name: format_prompt
    type: python
    source: tool.py
    inputs:
      question: ${data.question}
      context: ${data.context}
  - name: chat
    type: llm
    source:
      type: code
      path: chat.jinja2
    inputs:
      deployment_name: gpt-35-turbo
      max_tokens: 256
      temperature: 0.7
      chat_history:
      question: $(chat.output)
      response_format:
        type: text
```

- `data.jsonl` - each line is its own json

```jsonl
{"answer":"Final Answer: 3", "line_number": 0}
{"answer":"Final Answer: 13", "line_number": 1}
```

```python
from promptflow import PFClient

pf = PFClient()

run = pf.run(
    flow="flows/my_flow",                # path to flow directory
    data="data/inputs.jsonl",            # input dataset
    column_mapping={"question": "${data.question}", "context": "${data.context}"},
    run= {"name": "format-test-run"}
)

print(run.status)
```

- Flow.meta.yaml: Describes Flow name, inputs and outputs it expects, env info

```yaml
name: customer-support-qa
description: |
  A production-grade prompt flow for answering customer questions based on internal documentation using Azure OpenAI and a grounding tool.
version: 2.1.0
tags:
  environment: production
  owner: support-team
  component: qna
  business_unit: customer-experience

# Inputs to this flow
inputs:
  - name: question
    type: string
    description: The customer question to be answered.
    required: true
  - name: context
    type: string
    description: The documentation context retrieved from the knowledge base.
    required: true
  - name: language
    type: string
    default: "en"
    description: The target language for the answer (default is English).
  - name: temperature
    type: number
    default: 0.3
    description: Sampling temperature for the LLM response generation.

# Outputs from this flow
outputs:
  - name: answer
    type: string
    description: The final generated answer to the user’s question.
  - name: citations
    type: list
    description: List of sources or document sections used to form the answer.

# Reference to a specific environment version (registered in Azure ML or local build)
environment: azureml:promptflow-qa-env:2.5.1
```

- `connections.yaml` showing the connections to external AI, Blob services, etc.

```python
connections:
  azure_open_ai_connection:
    type: azure_open_ai
    api_base: https://my-openai-instance.openai.azure.com/
    api_key: "{{AZURE_OPENAI_API_KEY}}"  # Injected from environment
    api_version: "2024-05-01-preview"
    deployment_name: "gpt-4"

  blob_storage_connection:
    type: azure_blob_storage
    account_name: mystorageaccount
    account_key: "{{AZURE_BLOB_ACCOUNT_KEY}}"
    container: support-docs
```

- llm_extract_answer.jinja2

```jinja
system:
Role: Answer Extractor

Look at the input and try and select only the numerical answer.

{% for item in chat_history %}
user:
{{item.inputs.question}}
assistant:
{{items.outputs.answer}}
{% endfor %}

user:
{{question}}
```

### Develop RAG-based AI Foundry solution using own data

- One prevalent challenge when implementing language models through chat is `groundedness` (is the response rooted in reality or context).
    - If the language model doesn't include relevant trained info, it might lead to "invented" information.
    - `Ground` the prompt with relevant, factual context.
    - Use `RAG, Retrieval Augmented Generation` to ensure the agent is grounded on specific data, retrieving information that is relevant to intial prompt.

- **RAG Steps:**
1) `Retrieve` grounding data based on initial user-entered prompt.
2) `Augment` the prompt with grounding data.
3) Use Language model to `generate` a grounded response.

- AI Foundry supports **data connections** including: Blob storage, Data Lake Storage Gen2, OneLake.
    - You can also upload files from `AI Foundry` -> `myProject` -> `Playgrounds` -> `Chat Playground` -> `Select your data`.
    - You should *integrate with AI Search* to retreive the relevant info from your data uploads. **AI Search** is a `retriever` that you can include to bring your own data, index it, and query the index.

- You achieve a better data retreival by using a `vector-based index` (instead of text-based) that contains embeddings, a vector of floating-point numbers.
    - Distance between vectors (i.e. children vs kids, park vs playground) are measured by `cosine similarity`.

- Create a `Search Index`, which describes how your content is organized/searchable. 
- Indexes can be searched by:
    - Keyword search:
    - Semantic search:
    - Vector search:
    - Hybrid search:

- Azure OpenAI supports `.md`, `.txt`, `.html`, `.pdf`, `Word` and `Powerpoint` files.

- Steps to create a RAG based app:
1) Use AI Foundry project client to retrieve connection details for Search Index and OpenAI `ChatClient` object.
2) Add index connecton info to `ChatClient` config, so it can be searched for grounding data based on user prompt.
3) Submit the grounded prompt to Azure OpenAI model to generate contextualized response.

```python
from openai import AzureOpenAI

# Get an Azure OpenAI chat client
chat_client = AzureOpenAI(
    api_version = "2024-12-01-preview",
    azure_endpoint = open_ai_endpoint,
    api_key = open_ai_key
)

# Initialize prompt with system message
prompt = [
    {"role": "system", "content": "You are a helpful AI assistant."}
]

# Add a user input message to the prompt
input_text = input("Enter a question: ")
prompt.append({"role": "user", "content": input_text})

# Additional parameters to apply RAG pattern using the AI Search index
rag_params = {
    "data_sources": [
        {
            "type": "azure_search",
            "parameters": {
                "endpoint": search_url,
                "index_name": "index_name",
                "authentication": {
                    "type": "api_key",
                    "key": search_key,
                }
            }
        },
        # Params for vector-based query
        "query_type": "vector",
        "embedding_dependency": {
            "type": "deployment_name",
            "deployment_name": "<embedding_model_deployment_name>",
        },
    ],
}

# Submit the prompt with the index information
response = chat_client.chat.completions.create(
    model="<model_deployment_name>",
    messages=prompt,
    extra_body=rag_params
)

# Print the contextualized response
completion = response.choices[0].message.content
print(completion)
```

- To connect your data:
    - Navigate to `Chat` playground in AI Studio and select `Add your data`
    - Select `Add a data source` button
    - Take advantage of data field column mapping
    - The response model is limited to `1500 tokens` all in all when using your own data.

- **Prompt Flow options**:
    - Running custom Python code:
    - Lookup data values in index:
    - Create prompt variants:
    - Submitting prompt to LLM to generate results
    - Finally, flow has one or more `outputs`, typically to return the generated response.

- Clone the `Multi-round Q&A on your data` when you want to combine RAG and a LM in your app.
    (Inputs -> Modify_query_with_history -> Lookup -> generate_prompt_context.py -> Prompt_variants -> Chat_with_context -> outputs)

### Fine-tuning a language model with AI Foundry

- Within prompt engineering, `force` is a concept also known as `one-shot` or `few-shot` in terms of examples given to provide a desired output.

- `Fine-tuning` involves combining a (1) suitable foundational model as a base, with a (2) set of training data that includes example prompts, system message, and responses the model can learn from.

- Fine tuning example:
```json
{"messages": [{"role": "system", "content": "You are an Xbox customer support and know nothing of Playstation."}, {"role": "user", "content": "Is Xbox better than PlayStation?"}, {"role": "assistant", "content": "I apologize, but I cannot provide personal opinions on Playstation. Do you need info on Xbox?"}]}
```

- Multi-churn chat file format with weights:
```json
{"messages": [{"role": "system", "content": "Marv is a factual chatbot that is also sarcastic."}, {"role": "user", "content": "What's the capital of France?"}, {"role": "assistant", "content": "Paris", "weight": 0}, {"role": "user", "content": "Can you be more sarcastic?"}, {"role": "assistant", "content": "Paris, as if everyone doesn't know that already.", "weight": 1}]}
```

- When selecting a `base model`:
    - Model capabilities: For example, `BERT` is capable of understanding short texts.
    - Pretrained data:
    - Limitations and biases:
    - Language support:

- Configure the fine-tuning job:
1) Select Base model
2) Select training data
3) (optional) Select validation data
4) Configure advanced options
    - `batch_size`: number of training examples used to train a single forward and backward pass. Larger batch sizes work better for larger datasets.
        - Each batch updates the model once.
    - `learning_rate_multiplier`: experiment with values between .02 and .2. Larger for large batch sizes.
        - Fine tunes how fast the model learns. Too high is overshooting a solution, and too low is slow learning.
    - `n_epochs`: number of epochs, one full cycle through the training dataset.
        - *1* Epoch means the model has seen every sample in the training data *once*.
    - `seed`: controls reproducibility of the job, if a seed isn't specified, one is generated for you. 
        - Can use the same integer for closer results.

### Responsilbe Gen AI solution in Azure AI Foundry

- Four stage process to developing responsible GenAI (Corresponding to `NIST AI Risk Management Framework`):
1) `Map` potential harms:
    1) Identify potential harms (offensive, pejorative, inaccurate, illegal)
    2) Prioritize identified harms (take into account intended use and misuses)
    3) Test and verify the prioritized harms (`red teaming` is a test where you deliberately probe for weaknesses and harmful results)
    4) Document and share verified harms
2) `Measure` presence of these harms:
    1) Prepare diverse selevtion of input prompts likely to result in harm
    2) Submit prompts to system and retrieve output
    3) Apply pre-defined criteria to evaluate output and categorize
3) `Mitigate` the harms:
    1) Model layer: select appropriate model, fine-tuning
    2) Safety system: Platform level configurations, content filters.
    3) System message and grounding: system inputs and prompt engineering, RAG
    4) User Experience: applying input or output validation
4) `Manage` solution responsibly:
    - Common compliance reviews: legal, privacy, security, accessibility.
    - Devise a phased deliver plan
    - Incident response plan
    - Rollback plan
    - Track metrics and feedback
    - **Utilize AI Foundry Content Safety**: `Prompt shields`, `groundedness detection`, `protected material detection`, `custom categories`.

### Evaluate Gen AI performance in AI Foundry Portal
- Example Chat Flow: `Input -> Language Model -> Python Code -> Output`
- Commonly Used Benchmarks:
    - **Accuracy**: 1 if text matches, 0 otherwise.
    - **Coherence**: measures if output flows smoothly
    - **Fluency**: grammar, syntax, structure, vocab rules
    - **GPT similarity**: quantifies similarity between document (truth) and prediction.

- Visit `AI Foundry` -> `Model Catalog` on left blade -> `Model Benchmarks` -> Select `metrics to compare`.
- AI Assisted metrics: Generation quality and Risk/safety metrics
- NLP Metrics: 
    - `F1-score`: Text Classfication. Measures ratio of number of shared words between truth and generated answer.
        - Spam detection, sentiment analysis.
    - `BLEU`: Machine translation. Bilingual evaluation Understudy Metric.
        - Measures N-gram overlap between machine output and reference translations.
    - `METEOR`: Machine translation, paraphrasing. Metric for Evaluation of Translation with Explicit Ordering.
        - More flexible than BLEU, considers exact matches, stem metches, synonyms, paraphrases.
    - `ROUGE`: Text Summarization. Recall-Oriented Understudy Gisting Evaluation
        - Measures overlap of N-grams, words, sequences between references and candidate texts.

- Test your selected model in the `Chat playground`, where you can provide a deployment, system message, parameters and prompts.
- Use the `manual evaluations` feature to upload a dataset with multiple questions, and optional expected response.
    - You can rate the model's response with a Thumbs Up/Down.
- Use automated evaluations from `AI Foundry` -> `myProject` -> `Evaluation` on the left blade under `Protect and Govern`.
    - From here, `Create a new evaluation`: Test data, topics, model

### Develop Apps with Azure OpenAI in Foundry Models
- Search `Azure OpenAI` in the portal
    - Fill in subscription, RG, Region, Instance name, and pricing tier.
    - You can use `az cognitiveservices account create --kind OpenAI --sku s0`
- Once you create the account, you can visit at `https://ai.azure.com`
- Go to `Deployments` under `Shared resources`:
    - Here you can see `Model Deployments` (name, model name, model version, state, model retirement date) and `App deployments`.
- **Types of OpenAI models**: `GPT-4 models`, `GPT 3.5 models`, `GPT-35-turbo`, `Embeddings model`, `DALL-E models`, `Whisper models`, `text to speech models`
    - Pricing is determined by tokens and model type.
- From the `model catalog` page, you can create new deployments by selecting a model.

```bash
az cognitiveservices account deployment create \
   -g OAIResourceGroup \
   -n MyOpenAIResource \
   --deployment-name MyModel \
   --model-name gpt-35-turbo \
   --model-version "0125"  \
   --model-format OpenAI \
   --sku-name "Standard" \
   --sku-capacity 1
```

- Responses are referred to `completions` (text, code, other formats).

- **Prompt Type:**

|Task type|Prompt example|Completion example|
|---------|--------------|------------------|
|Classifying content|`Tweet: I enjoyed the trip. Sentiment:`|`Positive`|
|Generating new content|`List ways of traveling`|`1. Bike, 2. Car`|
|Holding a conversation|`A friendly AI assistant`|`I am an AI created by OpenAI. How can I help you today?` |
|Transformation| `English: Hello, French:`|`bonjour`|
|Picking up where left off|`One way to grow tomatoes`| `is to plant seeds.`|
|Giving factual responses|`How many moons does Earth have`| `One.` |

- In `Chat playground`, you can use prompt samples, adjust parameters, and add `few-shot` examples.
- Azure OpenAI REST API requires: `ENDPOINT`, `API_KEY`, `DEPLOYMENT_NAME`
```bash
curl https://ENDPOINT.openai.azure.com/openai/deployments/DEPLOYMENT_NAME/chat/completions?api-version=2023-03-15-preview \
  -H "Content-Type: application/json" \
  -H "api-key: API_KEY" \
  -d '{"messages":[{"role": "system", "content": "You are a helpful assistant, teaching people about AI."},
{"role": "user", "content": "Does Azure OpenAI support multiple languages?"},
{"role": "assistant", "content": "Yes, Azure OpenAI supports several languages, and can translate between them."},
{"role": "user", "content": "Do other Azure AI Services support translation too?"}]}'
```
- Sample response:

```json
{
    "id": "chatcmpl-6v7mkQj980V1yBec6ETrKPRqFjNw9",
    "object": "chat.completion",
    "created": 1679001781,
    "model": "gpt-35-turbo",
    "usage": {
        "prompt_tokens": 95,
        "completion_tokens": 84,
        "total_tokens": 179
    },
    "choices": [
        {
            "message":
                {
                    "role": "assistant",
                    "content": "Yes, other Azure AI Services also support translation. Azure AI Services offer translation between multiple languages for text, documents, or custom translation through Azure AI Services Translator."
                },
            "finish_reason": "stop",
            "index": 0
        }
    ]
}
```

- Embeddings:

```bash
curl https://ENDPOINT.openai.azure.com/openai/deployments/DEPLOYMENT_NAME/embeddings?api-version=2022-12-01 \
  -H "Content-Type: application/json" \
  -H "api-key: API_KEY" \
  -d "{\"input\": \"The food was delicious and the waiter...\"}"
```
- Example response:

```json
{
  "object": "list",
  "data": [
    {
      "object": "embedding",
      "embedding": [
        0.0172990688066482523,
        -0.0291879814639389515,
        ....
        0.0134544348834753042,
      ],
      "index": 0
    }
  ],
  "model": "text-embedding-ada:002"
}
```
- API Endpoints as ChatCompletion (gpt-35-turbo) or Completion (gpt-3) endpoints.
    - Be aware of `recency bias`, where recent messages influence prompt behavior.
- Model `Parameters` can be adjusted:
    - `temperature`: high temp allows for more variation or creativity.
    - `top_p`: more variation and variety of synonyms
- You can ground the prompt by providing context in between `--- context ---`

### Generate Images in Azure AI Foundry

- Example image generation models: `DALL-E 3`, `GPT-Image 1`
- Go to `AI Foundry` -> `Playgrounds` -> `Images playground`
    - Choose `Deployment`, write `prompt`
    - Under `Settings`:
        - Resolution (size): `1024x1024` up to `1792x1024`/`1024x1792`
        - Image style: `Vivid` or `Natural`
        - Image quality: `standard` or `hd`

- REST Payload to DALL-E:
```json
{
    "prompt": "A badger wearing a tuxedo",
    "n": 1,
    "size": "1024x1024",
    "quality": "hd", 
    "style": "vivid"
}

```
- Output includes a URL where image is located:
    - `Revised prompt` was used to generate the image, was updated by the system
```json
{
    "created": 1686780744,
    "data": [
        {
            "url": "<URL of generated image>",
            "revised_prompt": "<prompt that was used>"
        }
    ]
}
```

### Azure AI Foundry Agent Service
- Go to `AI Foundry` -> `Playgrounds` -> `Agents Playground`:
    - `+ New agent`: Model, Knowledge, Tools
    - `Setup`:
        - `Agent id`
        - `Agent name`
        - `Deployment`
        - `Instructions`
        - `agent Description`
        - `Knowledge`


## Develop AI Agents

- `AI Agents` are smart software combined with genAI models, which can operate autonomously to automate tasks, to orchestrate business processes and coordinate workloads.

- Example workflow:
    - User asks expense agent question about claimed expenses.
    - Expenses agent accepts question as prompt.
    - Agent uses knowledge store containing policy info to ground prompt.
    - Grounded prompt is submitted to language model for response.
    - Agent generates the claim information and submits it to be processed.

- You can use `AI Foundry Agent Service`, managed service to provide framework for creating, managing, using AI agents. Based on `OpenAI Assistants API`.
- Semantic Kernel (`Semantic Kernal Agent Framework`) is a lightweight, open-source development kit to build AI agents.
- `AutoGen` is an open-source framework for rapid agent development.
- `Microsoft 365 Agents SDK`: not actually limited to O365 apps, but can be used for Slack or Messenger.
- `Microsoft Copilot Studio` is a low code environment for citizen developers to quickly build agents.
- `Declarative` Copilot Studio agent builder tool can be used to author basic agents for common tasks.

- Agent Use Cases: Personal productivity agents, research agents, sales agents, customer service agents, developer agents (Copilot).

### Azure AI Foundry Agent Service

- **Azure AI Foundry Agent Service** Create AI agents through custom instructions, code interpreters and functions with minimal code.
    - Automatic tool calling: additional functionality available to the agent.
    - Securely managed data: Conversation state management with a stateful `thread`.
    - OOB tools: File retrieval, code interpretation, interaction with data sources/integrations.
    - Flexible Model selection: OepnAI, Llama 3, Mistral, Cohere.
    - Enterprise-grade security:
    - Customizable storage solutions: Fully managed platform or bring your own Azure blob.

- Go to `AI Foundry` -> `Playgrounds` -> `Agents Playground`:
    - `+ New agent`: Model, Knowledge, Tools
    - `Setup`:
        - `Agent id`
        - `Agent name`
        - `Deployment`
        - `Instructions`
        - `agent Description`
        - `Knowledge`

- A *standard* or comprehensive agent steup includes Foundry -> Project + Azure Key Vault, AI Search, AI Services, Azure storage.

#### Develop Multi-Agent Solution with Azure Foundry Agent Service

- **Connected Agents** are a feature in the Azure Foundry Agent Service that allows breaking larger tasks into smaller, specialized roles. A main agent interprets user input and delegates tasks to connected sub-agents.
    - Build modular solutions, assign specialized capabilities, scale systems intuitively, improved reliability/traceability.

- `Main Agent` responsibilities:
    - Interpret user input
    - Select appropriate connected agent
    - Forward relevant instructions
    - Aggregate/summarize results
- `Connected Agent` responsibilities:
    - Complete specific action based on clear prompt
    - Using tools if necessary
    - Return results to main agent

- Use the `create_agent` method of `AgentsClient` object to create an agents.


#### Agent Tools

- `Knowledge Tools` Grounds by enhancing context or knowledge available to agent:
    - **Bing Search**: Use bing search to ground prompts with real-time web data.
    - **File Search**: Data from files in a vector search.
    - **Azure AI Search**: Data from AI Search query results.
    - **Microsoft Fabric**: Fabric Data agent from your Fabric data stores.
- `Action Tools` perform an action or run a function:
    - **Code Interpreter**: Sandbox for model-generated Python code that can access/process uoploaded files.
    - **Custom Function**: Custom function code with definitions.
    - **Azure Function**: Call code in serverless Azure Functions.
    - **OpenAPI Spec**: Call external API based on OpenAPI 3.0 spec.

#### Integrate Custom Tools into your Agent

- Custom Tools in Foundry Agent Service enhance productivity, improve accuracy, and create tailored solutions, for example, access to an API that has weather data, inventory management, scheduling, IT help desk support.
    - **Custom Functions**: define a function that calls an external API and register it with your agent using Azure AI SDK with `toolset=toolset`
    - **Azure Functions**: Can implement as a queue trigger in Storage Account queue storage. The agent can then send requests to the Azure Function via queue storage and process the results. `tools=azure_function_tool.definitiions...`
    - **OpenAPI Specification tools**: Three authentication types are supported: `anonymous`, `API Key`, `managed identity`. A json file describing the API spec and python package `OpenApiTool`, `OpenApiAnonymousAuthDetails`
    - **Azure Logic Apps**:

- **Note**: By defining custom functions with meaninful names and well-documented parameters, the agent can "figure out" when and how to call a function.


#### Integrate MCP Tools with Azure AI Agents

- `Model Context Protocol (MCP)` servers integrate with AI agents to provide a catalog of tools accessible on demand.
    - **Dynamic tool discovery**: Latest Tools can be available without modifying agent code.
    - Use the `@mcp.tool decorator` to expose the functions/tools to the client. The MCP server hosts the available tools, and the MCP client discovers them
    - Initialize your MCP server: `FastMCP("server-name")`: Tools live on this server.
    - The MCP Client is the bridge between MCP Server and Azure AI Agent Service. Uses `session.list_tools()` and `session.call_tool`.
    - MCP Tools are wrapped in async functions on client-side to enable asynch invocation.

#### Develop an AI Agent with Semantic Kernel

- The **Semantic Kernel SDK** supports `ChatCompletionAgent`, `OpenAIAssistantAgent`, and `AzureAIAgent` and offers additional flexibility and scalability to your AI Agents, ensuring consistency, even across multi-agent solutions.

- **Semantic Kernel core components**:
    - `AI service connectors`: connect code to AI services (chat completion, text generation, etc.)
    - `Memory connectors`: expose vector stores from other providers.
    - `Functions and plugins`: containers for functions registered with the kernel, where they can be invoked. Use the `@kernel_function` decorator to create a plugin.
    - `Prompt templates`: combine instructions, input, function outputs into reusable format. Allow AI models to execute predefined steps dynamically.
    - `Filters`: custom actions to be peformed before and after function or prompt is invoked. Function filters act as outer layer, prompt filters act as inner layers.

- The **`AzureAIAgent` class** provides an enhanced way to interface with the Semantic Agent Framework like: simplified agent creation, automatic tool invocation, thread/conversation management, secure enterprise integration.

- **Agent Framework core Concepts**:
    - `Agent`: abstraction for AI agents, with subclasses like AzureAIAgent
    - `Agent Threads`: manage conversation state, stores conversations.
    - `Agent chat`: foundation for multi-agent interactions, structured collaboration and conversations.
    - `Agent channel`: custom agent development, allows different agents to participate in AgentChat
    - `Agent messages`: unified structure for agent communication, seamless integration with existing AI workflows.
    - `Templating`:  Semantic Kernel Prompt templates, use dynamic prompt configs.
    - `Functions and plugins`: extend agent capabilities.

- To use an `AzureAIAgent`:
1. Create an Azure AI Foundry project.
1. Add the project **connection string** to your Semantic Kernel application code.
1. Create an `AzureAIAgentSettings` object.
1. Create an `AzureAIAgent` client.
1. Create an agent definition on the agent service provided by the client.
1. Create an agent based on the definition.

- Create an AzureAIAgent:

```python
from azure.identity.aio import DefaultAzureCredential
from semantic_kernel.agents import AzureAIAgent, AzureAIAgentThread, AzureAIAgentSettings

# Create an AzureAIAgentSettings object
ai_agent_settings = AzureAIAgentSettings()

# Create an AzureAIAgent client
async with (@
    DefaultAzureCredential() as creds,
    AzureAIAgent.create_client(credential=creds) as client,
):
    # Create an agent definition on the agent service provided by the client
    agent_definition = await client.agents.create_agent(
        model=ai_agent_settings.model_deployment_name,
        name="<name>",
        instructions="<instructions>",
    )

    # Create the AI agent based on the agent definition
    agent = AzureAIAgent(
        client=client,
        definition=agent_definition,
    )
```

- Create a thread to interact with your agent:

```python
# Create the agent thread
thread: AzureAIAgentThread = AzureAIAgentThread(client=client)

try:
    # Create prompts 
    prompt_messages = ["What are the largest semiconductor manufacturing companies?"]

    # Invoke a response from the agent
    response = await agent.get_response(messages=prompt_messages, thread_id=thread.id)

    # View the response
    print(response)
finally:
    # Clean up the thread
    await thread.delete() if thread else None
```

#### Multi-Agent Solution using Semantic Kernel

- Multi-agent solutions allow agents to collaborate within the same conversation.
- Concepts of Agent Framework: Agents, `Agent collaboration` via agent group chat, Kernel, Tools and plugins, `History` (maintain a chat history across multiple interactions)

- `AgentGroupChat` allows dynamic, multi-agent conversations where different types of agents collaborate:

```python
# Define agents
agent_writer = AzureAIAgent(...)
agent_reviewer = AzureAIAgent(...)

# Create an empty chat
chat = AgentGroupChat()

# Add agents to an existing chat
chat.add_agent(agent=agent_writer)
chat.add_agent(agent=agent_reviewer)

# Add a chat message
await chat.add_chat_message(message=chat_message)
```

- `Single-turn conversations`: designated agent provides a response based on user input. Intent recognition, predefined rules.
- `Multi-turn conversations`: multiple agents take turns responding. Context tracking, dynamic switching.
    - Multi-turn agent selection is determined by a **`SelectionStrategy` class** which can be defnied when you create the `AgentGroupChat` object.
    - `SequentialSelectionStrategy`: order of agent turns based on order they were added to the chat. Option to specify initial agent.
    - `KernelFunctionSelectionStrategy`: create a kernel function prompt to create your own strategy based on a prompt.
    - `SelectionStratgey base class`: contains overridable select_agent where you can define custom logic.
    - Truncate chat history by passing a history_reducer parameter for the KernelFunctionSelectionStrategy: `history_reducer = ChatHistoryTruncationReducer(target_count=1)`
    - A `termination stratgegy` determines when the conversation should stop using. each supports `maxiumum_iterations`. Assign `termination_strategy` param of the AgentGroupChat object.
        - `DefaultTerminationStrategy`: class will only terminate after specified maximum_iterations
        - `KernelFunctionTerminationStrategy`: class allows you to define termination strategy based on prompt. Accepts `history_reducer` as well.
        - `TerminationStrategy base class`: contains overridable should_agent_terminate method to define custom logic.

## Develop Natural Language Solutions in Azure

### Analyze text with Azure AI Language

- Azure AI Language can be used for tasks like: Language detection, key phrase extraction, sentiment analysis, named entity recognition, entity linking.

- **Language detection** for documents must be `under 5,120 characters` per document and restricted to `1000 items (IDs)`.
    - Each contains an `id` and `text` to be analyzed, and you can provide a `countryHint`.
    - Will provide a LanguageDetectionResults kind json for each document. Confidence ranging from 0-1.
    - Mixed language content will return the language with the largest representation. or *predominant* langauge.
    - An *indecipherable* language will result in `(Unknown)` and confidenceScore of `0.0`

- **Key Phrase extraction** provides an `KeyPhraseExtractionResults` kind json with keyPhrases list per document.
- **Sentiment analysis** provides a `SentimentAnalysisResults` kind json with overall sentiment (positive, negative, or neutral) with the confidenceScores for each.
- **Named Entity recognition** identifies all named entities (known People "Joe", Locations "London", DateTimes "Saturday", Organizations, Address, Email, URL) with confidenceScores for each category in the `EntityRecognitionResults` json.
- **Entity Linking** can disambiguate entities of the same name by referencing an article, provides `EntityLinkingResults` kind json with associated articles url, dataSource, language.

### Create question answering solutions with AI Language

- Azure AI Language includes a question answering capability, which allows you to define a knowledge base of question/answer pairs that can be queried using natural language input.
    - Sources include: web sites containing FAQs, Structured text files like brochures or PDFs, Built-in chit-chat question/answer pairs to encapsulate common convos.

- **Note** that `Question answering` and `Language Understanding` serve distinct purposes and can be used in a single comprehensive solution to answer questions.
    - Can include a `multi-turn conversation`, where you ask follow up questions to get more info before providing a complete answer.

- Use the REST API or SDK, or Language Studio interface to manage your knowledge base.
- Search for `Azure AI Services`
    - Click `Create` under `Language Service` resource:
    - Create your resource
        - enable `question answering` feature
        - create or select `Azure AI Search` resource
    - In the `Language Studio`, add one or more `data sources`.
    - Edit question and answer pairs in the portal.

- Example request body for knowledge base:

```json
{
  "question": "What do I need to do to cancel a reservation?",
  "top": 2,
  "scoreThreshold": 20,
  "strictFilters": [
    {
      "name": "category",
      "value": "api"
    }
  ]
}
```

- Improve Question Answering performance by **Active Learning** (click `Review suggestions`, `Add alternate question` and iterate) and **Synonyms** (under alterations in JSON format)

- You can configure an `email channel` to create a bot that users can interact with via email.

### Build a Conversational Language Understanding Model

- AI Language comes preconfigured with features:
    - Summarization
    - Named Entity Recognition
    - PII Detection
    - Key Phrase Extraction
    - Sentiment Analysis
    - Language Detection
- AI Language Learned Features:
    - Conversational Language Understanding (CLU): predict overall intent and extract important info. Requires data to be tagged.
    - Custom Named Entity Recognition: Takes custom labled data and extracts entities.
    - Custom Text Classification
    - Question Answering

- Query using SDKs:

```python
language_client = TextAnalyticsClient(
            endpoint=endpoint, 
            credential=credentials)
response = language_client.extract_key_phrases(documents = documents)[0]
```

- **Uterrances** are phrases the user might enter.
    - Use Patterns to differentiate similar utterances (TurnOnDevice, GetDeviceStatus, TurnOffDevice might have similar utterances)
- **Intent** represents a task or action the user wants to perform, the meaning of an utterance. i.e. TurnOnDevice
    - `None` is an explicit intent for utterances like "Hello"
- **Entities** are used to add specific context to intents. i.e. the specific device to TurnOnDevice
    - **Learned** entities are flexible, and should be used in most cases.
    - **List** entities are useful for an entity with defined set of possible values. i.e. DaysOfWeek
    - **Prebuilt** entities are numbers, datetimes, names. You can have up to 5 prebuilt components per entity.

### Create a custom text classification solution with AI Language

- Azure AI Language Lifecycle: `Define Labels -> Tag Data with labels -> Train model -> View Model -> Improve model -> Deploy model -> Use model to classify text`
    - Use the Language Studio GUI or REST API

- **Single label classification**: Can only assign one class to each file. `customSingleLabelClassification` Project type.
- **Multiple label classification**: Assign multiple classes to each file. `customMultipleLabelClassification` Project type.

- Evaluation of the model is translated into three measures provided by AI Language: 
    - `Recall`: of all actual labels, how many identified TP. Are the labels being remembered, right or wrong?
    - `Precision`: ratio of TP to all identified positives. Is the entity labeled correctly?
    - `F1 Score`: function of recall and precision, to maximize balance of each.

- **Train** the model using either `automatic split` or `manual split` of Training (80%) and Testing (20%) datasets.

### Custom Named Entity Recognition

- An **entity** is a person, place, thing, event, skill, or value.
    - Break custom entities up into Phone, Email, rather than Contact info.

- Azure AI Language Entity Extraction Model: `Define Entities -> Tag Data with entities -> Train model -> View Model -> Improve model -> Deploy model -> Use model to extract entities`

- Task for Custom NER is `CustomEntityRecognition` for the JSON payload.

- **Project Limits**: Training (10-100,000 files), Deployments (10 per project), 1 Storage account per project, Entities (500 characters) Entity Types (200), API (10 POST, 100 GET/minute)

- From Language Studio: `Overview`, `Entity Type performance`, `Test set details`, `Dataset distribution`, `Confusion Matrix` blades

### Translate text with AI Translator Service

- Azure AI Translator supports 90 languages, features include: Language Detection, One-to-many translation, Script transliteration

- Use `Detect` function of the REST API to detect a language:

```bash
curl -X POST "https://api.cognitive.microsofttranslator.com/detect?api-version=3.0" -H "Ocp-Apim-Subscription-Region: <your-service-region>" -H "Ocp-Apim-Subscription-Key: <your-key>" -H "Content-Type: application/json" -d "[{ 'Text' : 'こんにちは' }]
```

- Use `Translate` function of REST API to translate from LANG to LANG `&from=ja&to=fr&to=en` :
    - `includeAlignment: true` parameter to resolve character alignment issues.
    - `includeSentenceLength: true` to know length of translation.
    - `profanityAction`: `NoAction`, `Deleted`, `Marked` (`profanityMarker: Tag`)

```bash
curl -X POST "https://api.cognitive.microsofttranslator.com/translate?api-version=3.0&from=ja&to=fr&to=en" -H "Ocp-Apim-Subscription-Key: <your-key>" -H "Ocp-Apim-Subscription-Region: <your-service-region>" -H "Content-Type: application/json; charset=UTF-8" -d "[{ 'Text' : 'こんにちは' }]"
```

- Use `Transliterate` function of REST API with fromScript param and toScript `fromScript=Jpan&toScript=Latn`:

```bash
curl -X POST "https://api.cognitive.microsofttranslator.com/transliterate?api-version=3.0&fromScript=Jpan&toScript=Latn" -H "Ocp-Apim-Subscription-Key: <your-key>" -H "Ocp-Apim-Subscription-Region: <your-service-region>" -H "Content-Type: application/json" -d "[{ 'Text' : 'こんにちは' }]"
```

### Create Speech-Enabled Apps

- **Azure AI Speech** supports: Real-time/fast/batch transcription, and custom speech. When using the API:
    1. Use `SpeechConfig` object to encapsulate `location` and `key`.
    1. (Optional) use `AudioConfig` if an audio file.
    1. Create the `SpeechRecognizer` object using `SpeechConfig` and `AudioConfig`
    1. Use methods of `SpeechRecognizer` like `RecognizeOnceAsync()`
    1. Process the `SpeechRecognitionResult` object (`Duration`, `OffsetInTicks`, `Properties`, `Reason`, `ResultId`, `Text`)
    1. If operation successful, `Reason` property contains `RecognizedSpeech` and `Text`, if unsuccessful, `CancellationReason`

- `SpeechSynthesizer` object works similarly, with AudioConfig to define the device to create the speech.

- Can choose between `Standard` (synthetic sounding) or `Nueral` (natural sounding) voices. `SpeechSynthesisVoiceName` property of SpeechConfig.

- **Speech Synthesis Markup Language SSML** syntax offers control over how spoken output sounds: Style, phonemes (phonetic pronounciation), prosody (pitch), say-as rules, insert background noise.

### Translate Speech with Azure AI Speech Service

- Pattern for Speech Translation using SDK:
    1. Use `SpeechTranslationConfig` object to encapsulate `location` and `key`.
    1. (Optional) use `AudioConfig` to define input source for audio to be transcribed.
    1. Create the `TranslationRecognizer` object as a proxy client for the Speech translation API using `SpeechTranslationConfig` and `AudioConfig`
    1. Use methods of `TranslationRecognizer` like `RecognizeOnceAsync()`
    1. Process the `SpeechRecognitionResult` object (`Duration`, `OffsetInTicks`, `Properties`, `Reason`, `ResultId`, `Text`, `Translations`)
    1. If operation successful, `Reason` property contains `RecognizedSpeech` and `Text`, and `Translations`. if unsuccessful, `CancellationReason`

- The **TranslationRecognizer** returns translated transcriptions of spoken input. Audio -> Text.
- **Event-based synthesis**: 1:1 translation to capture translation as audio stream. Needs `GetAudio()` method in event handler.
- **Manual synthesis**: alternative approach that doesn't require a handler. Iterates through translations dictionary.

### Develop an Audio-enabled GenAI app

- To handle prompts that include audio, you need to deploy a **multimodal** Gen AI model (Phi-4-multimodal, gpt-4o, gpt-4o-mini)
- In the **AI Foundry Chat Playground**: View Setup, Choose a voice, Add your data, Parameters, Evaluate, Import, Export, Deploy.

- Audio can be included in the `audio_url` as a url or binary data.

```json
{ 
    "messages": [ 
        { "role": "system", "content": "You are a helpful assistant." }, 
        { "role": "user", "content": [  
            { 
                "type": "text", 
                "text": "Transcribe this audio:" 
            },
            { 
                "type": "audio_url",
                "audio_url": {
                    "url": "https://....."
                }
            }
        ] } 
    ]
}
```

## Develop Computer Vision Solutions in Azure

### Analyze Images with Azure AI Vision

- **Azure AI Vision** can be used to analyze images and: Generate a caption, tag images, locate common objects, locate people.
    - AI Vision endpoint example: `https://<resource_name>.cognitiveservices.azure.com/`
    - Images must be in `JPEG`, `PNG`, `GIF`, `BMP` format
    - File size less than `4MB`
    - Dimensions must be greater than `50x50` pixels
    - Use the `analyze_from_url` method in python from `azure.ai.vision.imageanalysis` import `ImageAnalysisClient`, `VisualFeatures`

- `VisualFeatures` features include: `.TAGS`, `.OBJECTS`, `.CAPTION`, `.DENSE_CAPTIONS`, `.PEOPLE`, `.SMART_CROPS`, `.READ`

### Read Text in Images with AI Vision

- **Optical Character Recognition (OCR)** is part of Azure AI Vision Image Analysis API, used for text location/extraction, finding and reading text in photos, and Digital Asset Management (DAM) - usefule for cataloging and indexing.

- Azure AI Document Intelligence: Form processing, prebuilt models, custom models.
- Azure AI Content Understanding: Multimodal content extraction, custom content analysis

- With a Foundry or Computer Vision resource: `https://<endpoint>/computervision/imageanalysis:analyze?features=read&...`
    - JSON payload includes `readResult` that includes `blocks`, `lines`, `text` and `boundingPolygon` as well as `confidence` score.

### Detect, Analyze and Recognize faces

- Azure AI Vision `Face API` provides:
    - **Facial detection**: results include an ID that identifies face in the bounding box.
    - **Facial attribute analysis**: (Pose, glasses, mask, blur, exposure, noise, occlusion, accessories, quality).
    - **Facial Landmark location**: coordination of facial features.
    - **Face comparison**: compare for similarity and verification.
    - **Facial Recognition**: identify trained people in new images.
    - **Facial Liveness**: can check if real stream.

- For python: `from azure.ai.vision.face import FaceClient`
    - Use the Detect method.

```python
# Specify facial features to be retrieved
features = [FaceAttributeTypeDetection01.HEAD_POSE,
            FaceAttributeTypeDetection01.OCCLUSION,
            FaceAttributeTypeDetection01.ACCESSORIES]

# Use client to detect faces in an image
with open("<IMAGE_FILE_PATH>", mode="rb") as image_data:
    detected_faces = face_client.detect(
        image_content=image_data.read(),
        detection_model=FaceDetectionModel.DETECTION01,
        recognition_model=FaceRecognitionModel.RECOGNITION01,
        return_face_id=True,
        return_face_attributes=features,
    )
```

- **Persisted Face**: When identifying faces, create a `Person Group` and add a `Person` for each individual. Then the IDs/GUIDs of the faces will no longer expire after 24 hours. 

### Classify Images and Detect Objects with AI Custom Vision

- **Azure AI Custom Vision** service allows you to build your own image classification or object detection model.
    - *Requires* two Custom Vision resources: `(1) Custom Vision training` resource to train your custom model, and `(2) Custom Vision prediciton` resource to generate predictions from new images.
    - The client application needs the *endpoint* and key for the prediction resource, and the *project ID* of the image classification project, and the *name of the model* in order to connect to Custom Vision and classify an image.

- Python package: `from azure.cognitiveservices.vision.customvision.prediction import CustomVisionPredictionClient`


- Object detection prediction:
    - Class label of each object in the image
    - Location of each object within the image (bounding box)

- Use the `smart labeler tool` in the portal to suggest regions and classes of objects they contain after tagging initial images.

### Analyze Video with Azure Video Indexer service

- **Azure Video Indexer service** can be accessed at `https://www.videoindexer.ai/accounts` and is used for:
    - Facial recognition
    - OCR
    - Speech transcripton
    - Topics
    - Sentiment
    - Labels
    - Content moderation
    - Scene segmentation
    - Custom: You can extend the capabilities to include custom models for: `People`, `Languages`, and `Brands` you desire.

- Video Indexer API: `https://api.videoindexer.ai/Auth/<location>/Accounts/<accountId>/AccessToken`

### Develop Vision-enabled Gen AI App

- To handle prompts that include video, you need to deploy a **multimodal** Gen AI model (Phi-4-multimodal, gpt-4o, gpt-4o-mini)
    - Note, prompts for vision are **multi-part**, a user message of `text/audio` and an `image` item.

```python
# Get a chat client
openai_client = project_client.inference.get_azure_openai_client(api_version="2024-10-21")

# Get a response to image input
image_url = "https://github.com/MicrosoftLearning/mslearn-ai-vision/raw/refs/heads/main/Labfiles/gen-ai-vision/orange.jpeg"
image_format = "jpeg"
request = Request(image_url, headers={"User-Agent": "Mozilla/5.0"})
image_data = base64.b64encode(urlopen(request).read()).decode("utf-8")
data_url = f"data:image/{image_format};base64,{image_data}"

response = openai_client.chat.completions.create(
     model=model_deployment,
     messages=[
         {"role": "system", "content": system_message},
         { "role": "user", "content": [  
             { "type": "text", "text": prompt},
             { "type": "image_url", "image_url": {"url": data_url}}
         ] } 
     ]
)
print(response.choices[0].message.content)
```

## Develop AI Information Extraction Solutions in Azure

### Create multimodal analysis solution with Azure AI Content Understanding

- **Azure AI Content Understanding** is a Gen AI service that extracts insights from multiple kinds of content (Documents, Images, Audio, Video)
    - Content Understanding solutions are based on an `analyzer`, trained to extract specific information of a type based on a *schema* you define. You then use the analyzer to extract or generate `fields` from new content.

- From `Azure AI Foundry` -> `Content Understanding Overview` -> `Endpoints and Keys`, `Project Details`, `Included Capabilities`.
- From the `Define Schema` section: `+ Add new field`, `Field name`, `Field description`, `Value type` (string, date), `Method` (Extract, Generate)
    - You can then move to the `Test analyzer` section, where you can `Run analysis`, `^ Upload Test files`
    - In the `Build analyzer` section, `+ Build analyzer`: `Name`, `Description`,` Date built`, `Status`, `View Code`

- Example JSON body POST request to the `analyze` function:

```json
POST {endpoint}/contentunderstanding/analyzers/{analyzer}:analyze?api-version={api version}
{
  "url": "https://host.com/doc.pdf"
}
```

- Example GET endpoint using `results` function:

```bash
GET {endpoint}/contentunderstanding/analyzers/{analyzer}/results/1234abcd-1234-abcd-1234-abcd1234abcd?api-version={api version}
```

### Create an Azure AI Content Understanding Client App

- You need the `endpoint` and `key` for the Content Understanding REST API.

- The response from the PUT request includes `Operation-Location` in the header, which provides a `callback URL` to check the status with a GET request.

- The complete JSON response for a business card analysis will include the `result`: `analyzerId`, `contents`: `markdown`, `fields`, `valueString`, `kind` (document), `unit`, `pages`, `words`, `lines`, `etc`

```python
# (continued from previous code example)

# Iterate through the fields and extract the names and type-specific values
contents = result_json["result"]["contents"]
for content in contents:
    if "fields" in content:
        fields = content["fields"]
        for field_name, field_data in fields.items():
            if field_data['type'] == "string":
                print(f"{field_name}: {field_data['valueString']}")
```

### Use prebuilt Document Intelligence Models

- When calling **Azure AI Document Intelligence** API, you need the `service endpoint` and `API Key`

- **Prebuilt Models** include: Invoice, Receipt, US Tax, ID Document, Business Card, Pay Stub, etc.
    - Prebuilt modesl are flexible, and you can increase accuracy by providing a high-quality document (JPEG, PNG, BMP, TIFF, PDF, 500MB, 50x50->10,000x10,000 pixels, PDF dimensions 17x17 and no password protection)
    - For multi-page PDF or TIFF, use `pages` param to fix page range for analysis.
- **Generalized Prebuilt Models**:
    - Read model: Extracts text and languages from docs. Only accepts Microsoft Office files.
    - General Document Model: Extract text, keys, values, entities, selection marks (choices like radio buttons, checkboxes) from docs.
    - Layout Model: Extract text and structure info from docs.

- Example document intelligence analyzer:

```python
poller = document_analysis_client.begin_analyze_document(
        "prebuilt-layout", AnalyzeDocumentRequest(url_source=docUrl
    ))
result: AnalyzeResult = poller.result()
```

- When using the `ID Document model`, make sure you have the permissions to store their data.

### Extract data from forms with Document Intelligence

- **Azure Document Intelligence**, a Vision API that extracts key-valye pairs and table data from documents, service use cases: process automation, knowledge mining, industry specific.
    - OCR captures the doc structure by creating `bounding boxes` around detected objects.
    - Total size of training data set must be 500 pagers or less.

- `Document Analysis Models`: JPEG, PNG, PDF, TIFF -> reutrns json file with location of text, bounding boxes, text, tables, selection marks, structure.
- `Prebuilt models`: W-2 forms, Invoices, Receipts, ID Documents, Business Cards.
- `Custom models`: Custom models can be trained via **Document Intelligence Studio**
    - Use the Analyze document function to create an ocr.kson file, and you need a single `fields.json` file describing the fields to extract. a `labels.json` file 
    - Use Document Intelligence studio to train by: `Custom template models` or `Custom neural models`.

- Score of ~100% is necessary for `confidence` value, ~80% for low-risk applications.

### Create a knowledge mining solution with Azure AI Search

- **Azure AI Search** allows you to extract, enrich, explore (indexing and querying) information from a variety of data sources.
    - Use cases: Support RAG AI apps by using vector-based indexes.
    - Built in `Skills`: Detect language, extract key entities, translation, generating captions, etc.

- An `index` contains your searchable content, and is created/updated by an `indexer`.
    - The indexer automates extraction/indexing of `fields` via `enrichment pipeline`, where it applies `document cracking` to create a hierarchical JSON-based document.
    - Fields extracted directly from source data are all mapped to index fields, these are `implicit`.
    - Output fields from the `skills` in the `skillset` are `explicitly` mapped to the target field in the index.

```markdown
# Typical structure
- document
    - metadata_storage_name
    - metadata_author
    - content
    - normalized_images
        - image_0
            - text
        - image_1
    - language
    - merged_content

```

- Each index field can be configured with **attributes**:
    - `key`: define a unique key for index records.
    - `searchable`: can be queried using full-text search.
    - `filterable`: can be included in filter expressions.
    - `sortable`: can be used to order results.
    - `facetable`: can be used to determine values for facets (user interface elements like checkboxes, dropdowns, category lists)
    - `retrievable`: can be included in a search result (by default, all fields are retrievable unless explicitly removed)

- Azure AI Search supports two variants of Lucene query syntax:
    - Simple: intuitive syntax for basic searches to match literal queries
    - Full: extended syntax supports complex filtering, regex, etc.

- **Common search parameters** submitted with a query: `search`, `queryType` (simple/full), `searchFields`, `select`, `searchMode` (Any)

- **Query Processing stages (4)**:
1. **Query parsing**: search expression reconstructed as subqueries
1. **Lexical analysis**: analyze based on linguistic rules
1. **Document retreival**: set of matching documents identified
1. **Scoring**: Term Frequency (TF)/Inverse Document Frequency (IDF) relevance scores.

```bash
# REST Parameters
search=London
$filter=author eq 'Reviewer'
queryType=Full
facet=author
$orderby=last_modified desc
```

- Azure AI Search supports a `knowledge store` you define in the skillset that encapsulates your enrichment pipeline. Consists of `projections` of enriched data, JSON objects.

## Responsible AI

- `Fairness`: treat all people and groups equitably, avoiding bias and discrimination.
- `Reliability and Safety`: perform consistently and safely under intended condtions.
- `Privacy and Security`: protect user data and resist misuse.
- `Inclusivness`: should be accessible and usable by people of all abilities and backgrounds.
- `Transparency`: decisions and behaviors are explainable and understandable.
- `Accountability`: organizations and developers are responsible for outcomes of AI systems.