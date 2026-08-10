# AWS Lambda Complete Guide (Simple to Intermediate)

## What is AWS Lambda?

**Lambda = Serverless Computing**

```
Traditional Server:
├─ Running 24/7 (even if not used)
├─ You manage: OS, updates, patches
├─ You pay: Always
└─ Most time: Idle (wasting money)

AWS Lambda:
├─ Runs only when triggered
├─ AWS manages: Everything
├─ You pay: Only execution time
└─ No servers to manage! ✓
```

**Simple Definition:** Write a function, AWS runs it when triggered, pay only for execution time.

---

# Part 1: Simple Lambda

## Concept 1: Event-Driven

```
Something Happens → Lambda Triggers → Function Runs

Examples:

File uploaded to S3
    ↓
Lambda triggered
    ↓
Function processes file

API request received
    ↓
Lambda triggered
    ↓
Function returns response

Database changed
    ↓
Lambda triggered
    ↓
Function reacts
```

---

## Step 1: Create Your First Lambda Function

### In AWS Console:

```
1. Go to: Lambda → Functions
2. Click: "Create function"
3. Fill in:
   ├─ Function name: "hello-world"
   ├─ Runtime: "Python 3.12"
   ├─ Architecture: "x86_64"
   ├─ Execution Role: "Create new role with basic Lambda permissions"
   └─ Click: "Create function"

Result: Function created! ✅
```

---

## Step 2: Write Your First Lambda Code

### Default Code (In AWS Console):

```python
def lambda_handler(event, context):
    return 'Hello from Lambda!'
```

**Replace with:**

```python
import json

def lambda_handler(event, context):
    """
    Simple greeting function
    
    Parameters:
    - event: Input data (what triggered the function)
    - context: Metadata about execution
    
    Returns:
    - Response dictionary
    """
    
    # Get name from event (or use default)
    name = event.get('name', 'Guest')
    
    # Create response
    response = {
        'statusCode': 200,
        'message': f'Hello {name}!'
    }
    
    return response
```

**Then click: "Deploy"** ✅

---

## Step 3: Test Your Function

### In AWS Console:

```
1. Click: "Test" button
2. Create test event:
   ├─ Event name: "test-greeting"
   ├─ Event JSON:
   │  {
   │    "name": "John"
   │  }
   └─ Click: "Save"

3. Click: "Test" again
   └─ Function executes

Result:
{
  "statusCode": 200,
  "message": "Hello John!"
}

Status: Success ✅
Duration: ~2ms
```

---

# Part 2: Understanding Events & Context

## What is Event?

**Event = Input data that triggers Lambda**

```python
def lambda_handler(event, context):
    # event contains the trigger data
    # event structure depends on trigger type
    pass
```

### Different Triggers = Different Event Structures

**Example 1: API Gateway (HTTP Request)**
```python
event = {
    "httpMethod": "GET",
    "path": "/users",
    "queryStringParameters": {"id": "123"},
    "headers": {"Content-Type": "application/json"},
    "body": None
}
```

**Example 2: S3 (File Upload)**
```python
event = {
    "Records": [
        {
            "s3": {
                "bucket": {"name": "my-bucket"},
                "object": {"key": "uploaded-file.jpg"}
            },
            "eventName": "ObjectCreated:Put"
        }
    ]
}
```

**Example 3: DynamoDB (Database Change)**
```python
event = {
    "Records": [
        {
            "eventSource": "aws:dynamodb",
            "eventName": "INSERT",
            "dynamodb": {
                "NewImage": {
                    "user_id": {"N": "123"},
                    "name": {"S": "John"}
                }
            }
        }
    ]
}
```

**Example 4: CloudWatch (Scheduled)**
```python
event = {
    "source": "aws.events",
    "detail-type": "Scheduled Event",
    "time": "2024-01-15T10:00:00Z"
}
```

---

## What is Context?

**Context = Metadata about Lambda execution**

```python
def lambda_handler(event, context):
    # Useful context properties:
    
    print(context.function_name)
    # Output: "hello-world"
    
    print(context.function_version)
    # Output: "$LATEST"
    
    print(context.memory_limit_in_mb)
    # Output: "128"
    
    print(context.aws_request_id)
    # Output: "unique-id-for-tracking"
    
    print(context.get_remaining_time_in_millis())
    # Output: "14000" (milliseconds before timeout)
    
    return {"message": "done"}
```

---

# Part 3: Simple Triggers & Configuration

## Trigger 1: API Gateway (HTTP Requests)

**Scenario: Call Lambda via HTTP**

### Setup in AWS Console:

```
1. Go to: Your Lambda function
2. Click: "Add trigger"
3. Choose:
   ├─ Trigger type: "API Gateway"
   ├─ API: "Create a new API"
   ├─ API type: "REST API"
   ├─ Security: "OPEN"
   └─ Click: "Add"

Result: API Gateway created ✅
You get URL: https://xxxxx.execute-api.us-east-1.amazonaws.com/default/hello-world
```

### Function Code:

```python
import json

def lambda_handler(event, context):
    """
    API Gateway triggers this
    event contains: HTTP method, path, body, headers
    """
    
    # Parse request
    method = event.get('httpMethod')
    body = json.loads(event.get('body', '{}')) if event.get('body') else {}
    
    # Get query parameters
    query_params = event.get('queryStringParameters', {})
    name = query_params.get('name', 'Guest') if query_params else 'Guest'
    
    # Create response
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({
            'message': f'Hello {name}!',
            'method': method
        })
    }
```

### Call Your Lambda:

```bash
# Method 1: Query string
curl https://xxxxx.execute-api.us-east-1.amazonaws.com/default/hello-world?name=John

# Method 2: POST with body
curl -X POST https://xxxxx.execute-api.us-east-1.amazonaws.com/default/hello-world \
  -H "Content-Type: application/json" \
  -d '{"name":"John"}'

Response:
{
  "message": "Hello John!",
  "method": "GET"
}
```

---

## Trigger 2: S3 (File Upload)

**Scenario: Run Lambda when file uploaded to S3**

### Setup in AWS Console:

```
1. Go to: Your Lambda function
2. Click: "Add trigger"
3. Choose:
   ├─ Trigger type: "S3"
   ├─ Bucket: Select your S3 bucket
   ├─ Event type: "All object create events"
   │  (or specific: PUT, POST, COPY)
   ├─ Prefix: (optional) "uploads/"
   ├─ Suffix: (optional) ".jpg"
   └─ Click: "Add"

Result: S3 trigger configured ✅
```

### Function Code:

```python
import boto3

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    S3 triggers this when file uploaded
    event contains: bucket name, object key
    """
    
    # Extract S3 info
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    event_name = event['Records'][0]['eventName']
    
    print(f"Processing file: {key}")
    print(f"From bucket: {bucket}")
    print(f"Event type: {event_name}")
    
    # Download file from S3
    response = s3_client.get_object(Bucket=bucket, Key=key)
    file_content = response['Body'].read().decode('utf-8')
    
    # Process file
    line_count = len(file_content.split('\n'))
    
    return {
        'statusCode': 200,
        'message': f'Processed {key}',
        'line_count': line_count
    }
```

### Test:

```bash
# Upload file to S3
aws s3 cp data.txt s3://my-bucket/uploads/data.txt

# Lambda automatically triggers
# Check CloudWatch Logs to see output
```

---

## Trigger 3: DynamoDB (Database Changes)

**Scenario: React when data changes in DynamoDB**

### Setup in AWS Console:

```
1. Go to: Your Lambda function
2. Click: "Add trigger"
3. Choose:
   ├─ Trigger type: "DynamoDB"
   ├─ Table: Select your DynamoDB table
   ├─ Batch size: "100"
   ├─ Starting position: "LATEST"
   └─ Click: "Add"

Result: DynamoDB trigger configured ✅
```

### Function Code:

```python
def lambda_handler(event, context):
    """
    DynamoDB stream triggers this when data changes
    event contains: INSERT, UPDATE, or DELETE records
    """
    
    for record in event['Records']:
        event_name = record['eventName']  # INSERT, UPDATE, DELETE
        dynamodb = record['dynamodb']
        
        if event_name == 'INSERT':
            new_image = dynamodb.get('NewImage')
            print(f"New record inserted: {new_image}")
        
        elif event_name == 'UPDATE':
            new_image = dynamodb.get('NewImage')
            old_image = dynamodb.get('OldImage')
            print(f"Record updated from {old_image} to {new_image}")
        
        elif event_name == 'DELETE':
            old_image = dynamodb.get('OldImage')
            print(f"Record deleted: {old_image}")
    
    return {'statusCode': 200, 'message': 'Processed'}
```

---

## Trigger 4: CloudWatch (Scheduled)

**Scenario: Run Lambda every hour automatically**

### Setup in AWS Console:

```
1. Go to: Your Lambda function
2. Click: "Add trigger"
3. Choose:
   ├─ Trigger type: "EventBridge (CloudWatch Events)"
   ├─ Schedule: "rate(1 hour)"
   │  (Options: rate(5 minutes), rate(30 minutes), cron(...))
   ├─ Name: "hourly-job"
   └─ Click: "Add"

Result: Scheduled trigger configured ✅
Lambda runs every hour automatically!
```

### Function Code:

```python
from datetime import datetime

def lambda_handler(event, context):
    """
    CloudWatch triggers this on schedule
    """
    
    print(f"Scheduled job running at: {datetime.now()}")
    
    # Do something
    result = perform_maintenance_task()
    
    print(f"Job completed: {result}")
    
    return {'statusCode': 200, 'message': 'Job completed'}

def perform_maintenance_task():
    # Clean old data, generate reports, etc.
    return 'Task done'
```

---

# Part 4: Intermediate - Real-World Examples

## Example 1: Save Data to DynamoDB

**Scenario: API → Lambda → Save to DynamoDB**

### Function Code:

```python
import json
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('Users')

def lambda_handler(event, context):
    """
    API Gateway triggers this
    Saves user data to DynamoDB
    """
    
    try:
        # Parse request
        body = json.loads(event.get('body', '{}'))
        
        # Validate input
        if not body.get('name') or not body.get('email'):
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'name and email required'})
            }
        
        # Create user ID (timestamp-based)
        user_id = str(int(datetime.now().timestamp()))
        
        # Save to DynamoDB
        table.put_item(Item={
            'user_id': user_id,
            'name': body['name'],
            'email': body['email'],
            'created_at': datetime.now().isoformat()
        })
        
        # Return success
        return {
            'statusCode': 201,
            'body': json.dumps({
                'user_id': user_id,
                'message': 'User created successfully'
            })
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }
```

### Test:

```bash
curl -X POST https://your-api/endpoint \
  -H "Content-Type: application/json" \
  -d '{"name":"John","email":"john@example.com"}'

Response:
{
  "user_id": "1234567890",
  "message": "User created successfully"
}
```

---

## Example 2: Process S3 File & Save Results

**Scenario: S3 upload → Process → Save results → Notify**

### Function Code:

```python
import json
import boto3
from datetime import datetime

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
sns_client = boto3.client('sns')

table = dynamodb.Table('FileProcessing')

def lambda_handler(event, context):
    """
    S3 triggers this when CSV file uploaded
    Processes file and saves results
    """
    
    try:
        # Extract S3 info
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = event['Records'][0]['s3']['object']['key']
        
        print(f"Processing file: s3://{bucket}/{key}")
        
        # Download file
        response = s3_client.get_object(Bucket=bucket, Key=key)
        file_content = response['Body'].read().decode('utf-8')
        
        # Process file
        lines = file_content.strip().split('\n')
        record_count = len(lines) - 1  # Exclude header
        
        # Save results to DynamoDB
        processing_id = f"{key}_{int(datetime.now().timestamp())}"
        table.put_item(Item={
            'file_name': key,
            'processing_id': processing_id,
            'record_count': record_count,
            'status': 'completed',
            'processed_at': datetime.now().isoformat()
        })
        
        # Send notification
        sns_client.publish(
            TopicArn='arn:aws:sns:us-east-1:123456:file-processed',
            Subject='File Processing Complete',
            Message=f'File {key} processed successfully.\nRecords: {record_count}'
        )
        
        print(f"Successfully processed {record_count} records")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'file': key,
                'records': record_count,
                'status': 'success'
            })
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
```

---

## Example 3: Multiple Triggers (Same Function)

**Scenario: Same function handles different triggers**

### Function Code:

```python
import json

def lambda_handler(event, context):
    """
    Handles multiple trigger types
    Checks event structure to determine trigger type
    """
    
    # Determine trigger type
    if 'Records' in event and 's3' in event['Records'][0]:
        return handle_s3_trigger(event)
    
    elif 'Records' in event and 'dynamodb' in event['Records'][0]:
        return handle_dynamodb_trigger(event)
    
    elif 'httpMethod' in event:
        return handle_api_trigger(event)
    
    elif 'source' in event and event['source'] == 'aws.events':
        return handle_scheduled_trigger(event)
    
    else:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Unknown trigger type'})
        }

def handle_s3_trigger(event):
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    return {'statusCode': 200, 'message': f'S3: Processing {key}'}

def handle_dynamodb_trigger(event):
    event_name = event['Records'][0]['eventName']
    return {'statusCode': 200, 'message': f'DynamoDB: {event_name} event'}

def handle_api_trigger(event):
    body = json.loads(event.get('body', '{}'))
    return {'statusCode': 200, 'body': json.dumps({'message': 'API called'})}

def handle_scheduled_trigger(event):
    return {'statusCode': 200, 'message': 'Scheduled job running'}
```

---

## Example 4: Environment Variables & Configuration

**Scenario: Use environment variables instead of hardcoding values**

### Setup in AWS Console:

```
Lambda function → Configuration → Environment variables

Add:
├─ TABLE_NAME = "Users"
├─ BUCKET_NAME = "my-bucket"
├─ SNS_TOPIC_ARN = "arn:aws:sns:..."
└─ API_ENDPOINT = "https://api.example.com"
```

### Function Code:

```python
import os
import boto3

# Read from environment variables
table_name = os.environ.get('TABLE_NAME')
bucket_name = os.environ.get('BUCKET_NAME')
topic_arn = os.environ.get('SNS_TOPIC_ARN')
api_endpoint = os.environ.get('API_ENDPOINT')

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Uses environment variables for configuration
    """
    
    print(f"Using table: {table_name}")
    print(f"Using bucket: {bucket_name}")
    
    # Use in code
    item = {
        'id': '123',
        'data': 'test'
    }
    
    table.put_item(Item=item)
    
    return {'statusCode': 200, 'message': 'Done'}
```

**Benefits:**
```
✓ Change config without modifying code
✓ Different values for dev/prod
✓ Keep secrets separate
✓ No hardcoding sensitive data
```

---

## Example 5: Error Handling

**Scenario: Handle errors gracefully**

### Function Code:

```python
import json

def lambda_handler(event, context):
    """
    Proper error handling
    """
    
    try:
        # Your code
        data = process_data(event)
        
        return {
            'statusCode': 200,
            'body': json.dumps(data)
        }
    
    except ValueError as e:
        # Specific error: value error
        print(f"ValueError: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Invalid input: ' + str(e)})
        }
    
    except KeyError as e:
        # Specific error: missing key
        print(f"KeyError: {str(e)}")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing field: ' + str(e)})
        }
    
    except Exception as e:
        # Catch all other errors
        print(f"Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }

def process_data(event):
    # Simulated data processing
    if 'data' not in event:
        raise ValueError('data field missing')
    return {'processed': event['data']}
```

---

## Example 6: Logging & Debugging

**Scenario: Log important information for debugging**

### Function Code:

```python
import json
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Logging for debugging and monitoring
    """
    
    # Log invocation
    logger.info(f"Function invoked with event: {json.dumps(event)}")
    logger.info(f"Request ID: {context.aws_request_id}")
    
    try:
        # Process
        result = process_request(event)
        
        logger.info(f"Successfully processed request")
        logger.debug(f"Result: {result}")  # Debug level (less verbose)
        
        return {
            'statusCode': 200,
            'body': json.dumps(result)
        }
    
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}", exc_info=True)
        # exc_info=True includes full stack trace
        
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }

def process_request(event):
    logger.info("Starting request processing")
    # Your logic
    logger.info("Request processing complete")
    return {'status': 'success'}
```

**View Logs:**
```
AWS Console → CloudWatch → Log Groups → /aws/lambda/function-name
├─ Logs organized by date
├─ Each invocation shows logs
├─ Search by request ID
└─ Useful for debugging
```

---

## Example 7: Call External API

**Scenario: Lambda calls external service**

### Function Code:

```python
import json
import requests
import os

API_KEY = os.environ.get('EXTERNAL_API_KEY')

def lambda_handler(event, context):
    """
    Calls external API
    """
    
    try:
        # Extract data
        user_email = event.get('email')
        
        if not user_email:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'email required'})
            }
        
        # Call external API
        response = requests.post(
            'https://api.external-service.com/verify',
            json={'email': user_email},
            headers={'Authorization': f'Bearer {API_KEY}'},
            timeout=5
        )
        
        # Check response
        if response.status_code == 200:
            data = response.json()
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'verified': data.get('verified'),
                    'message': 'Email verification complete'
                })
            }
        else:
            return {
                'statusCode': response.status_code,
                'body': json.dumps({'error': 'External API error'})
            }
    
    except requests.Timeout:
        print("API call timed out")
        return {
            'statusCode': 504,
            'body': json.dumps({'error': 'Service timeout'})
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }
```

---

# Part 5: Lambda Configuration & Permissions

## Function Configuration

### Basic Settings:

```
Lambda console → Configuration → General

Memory: 128 MB (default)
├─ Range: 128 MB - 10,240 MB
├─ More memory = Faster CPU
├─ More memory = More cost
└─ For image processing: 512-1024 MB

Timeout: 15 seconds (default)
├─ Range: 1 second - 900 seconds (15 minutes)
├─ If function takes longer: Automatically stopped
└─ For API: 30 seconds usually fine

Ephemeral storage: 512 MB (default)
├─ Range: 512 MB - 10,240 MB
├─ For temporary files during execution
└─ For image processing: 1-2 GB
```

### Environment Variables:

```
Configuration → Environment variables

Add key-value pairs:
├─ TABLE_NAME: Users
├─ BUCKET_NAME: my-bucket
├─ API_KEY: secret-key-123
└─ DEBUG: true
```

---

## IAM Permissions (Execution Role)

**Lambda needs permission to use AWS services**

### Default Role:

```
Created automatically when you create function:
├─ Name: lambda-basic-execution
├─ Permission: Write logs to CloudWatch
└─ Can access: CloudWatch Logs only
```

### Add Permissions:

```
Lambda console → Configuration → Permissions

Click on "Execution role" name
    ↓
Opens IAM console
    ↓
Click: "Add inline policy"
    ↓
Choose: JSON editor
    ↓
Paste policy for service you need:

For DynamoDB access:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:123456:table/Users"
    }
  ]
}

For S3 access:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-bucket/*"
    }
  ]
}

For SNS access:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": "arn:aws:sns:us-east-1:123456:my-topic"
    }
  ]
}
```

---

# Part 6: Lambda Pricing & Cost

## How Lambda is Priced

```
Requests:
├─ $0.20 per 1 million requests
├─ Example: 1 million requests = $0.20
└─ FREE: First 1 million/month

Execution time:
├─ $0.0000166667 per GB-second
├─ Example: 256 MB for 1 second = $0.0000041667
├─ Example: 512 MB for 1 second = $0.0000083333
└─ FREE: First 400,000 GB-seconds/month (total)
```

### Cost Example:

```
Scenario: API with 1 million requests/month

Per request:
├─ Memory: 256 MB
├─ Execution time: 200 ms (0.2 seconds)
├─ Cost per request: 0.2s × 0.256 GB × $0.0000166667 = $0.00000086
└─ 1 million requests × $0.00000086 = $0.86

Plus requests:
├─ 1 million requests = $0.20
└─ Total: $0.86 + $0.20 = $1.06/month ✓

vs Traditional Server:
├─ Basic server: $10-20/month minimum
└─ Lambda: $1/month (99% cheaper!)
```

---

# Part 7: Complete Flow Example

## Full Example: User Registration API

### Requirements:

```
1. User sends: POST /register with name, email, password
2. Lambda validates input
3. Lambda saves to DynamoDB
4. Lambda sends verification email via SNS
5. Lambda returns user ID and status
```

### Function Code:

```python
import json
import boto3
from datetime import datetime
import re

# Initialize AWS services
dynamodb = boto3.resource('dynamodb')
sns = boto3.client('sns')

users_table = dynamodb.Table('Users')

def lambda_handler(event, context):
    """
    User registration API
    """
    
    try:
        # Log invocation
        print(f"Registration request: {event}")
        
        # Parse request
        body = json.loads(event.get('body', '{}'))
        
        # Extract fields
        name = body.get('name', '').strip()
        email = body.get('email', '').strip()
        password = body.get('password', '')
        
        # Validate input
        validation_error = validate_input(name, email, password)
        if validation_error:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': validation_error})
            }
        
        # Check if user exists
        if user_exists(email):
            return {
                'statusCode': 409,
                'body': json.dumps({'error': 'User already exists'})
            }
        
        # Create user ID
        user_id = str(int(datetime.now().timestamp()))
        
        # Save to DynamoDB
        users_table.put_item(Item={
            'user_id': user_id,
            'email': email,
            'name': name,
            'password': password,  # In production: hash this!
            'created_at': datetime.now().isoformat(),
            'verified': False
        })
        
        # Send verification email via SNS
        send_verification_email(email, user_id)
        
        # Return success
        return {
            'statusCode': 201,
            'body': json.dumps({
                'user_id': user_id,
                'email': email,
                'message': 'User registered. Check email for verification.'
            })
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }

def validate_input(name, email, password):
    """Validate registration input"""
    
    if not name or len(name) < 2:
        return 'Name must be at least 2 characters'
    
    if not email or not is_valid_email(email):
        return 'Valid email required'
    
    if not password or len(password) < 6:
        return 'Password must be at least 6 characters'
    
    return None

def is_valid_email(email):
    """Check email format"""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return re.match(pattern, email) is not None

def user_exists(email):
    """Check if user already registered"""
    
    try:
        response = users_table.get_item(Key={'email': email})
        return 'Item' in response
    except:
        return False

def send_verification_email(email, user_id):
    """Send verification email via SNS"""
    
    topic_arn = 'arn:aws:sns:us-east-1:123456:user-verification'
    
    sns.publish(
        TopicArn=topic_arn,
        Subject='Email Verification Required',
        Message=f'Click here to verify: https://example.com/verify?user_id={user_id}'
    )
```

### Test API:

```bash
# Register user
curl -X POST https://your-api/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "password": "SecurePassword123"
  }'

Response:
{
  "user_id": "1234567890",
  "email": "john@example.com",
  "message": "User registered. Check email for verification."
}
```

---

# Summary: Lambda Development Checklist

```
✓ Understand event-driven architecture
✓ Know how to write lambda_handler function
✓ Understand different trigger types
✓ Know how to configure triggers in console
✓ Know how to use environment variables
✓ Know how to add IAM permissions
✓ Know how to access AWS services (S3, DynamoDB, SNS)
✓ Know how to handle errors properly
✓ Know how to log for debugging
✓ Know how to test functions in console
✓ Know how to monitor with CloudWatch
✓ Know basic Lambda pricing
✓ Know how to call external APIs
✓ Know how to structure responses
```

---

## Quick Reference: Common Lambda Patterns

### Pattern 1: API Endpoint
```
API Gateway → Lambda → Database
```

### Pattern 2: File Processing
```
S3 Upload → Lambda → Process → Save Results
```

### Pattern 3: Data Pipeline
```
DynamoDB Change → Lambda → External Service → Notify
```

### Pattern 4: Scheduled Job
```
CloudWatch Schedule → Lambda → Maintenance Task
```

### Pattern 5: Message Queue
```
SNS/SQS → Lambda → Action
```

---

## Next Steps

```
To deepen knowledge:
1. Explore AWS SDK documentation
2. Build more complex projects
3. Integrate multiple services
4. Monitor and optimize performance
5. Learn about advanced patterns (covered in Advanced section)
```
