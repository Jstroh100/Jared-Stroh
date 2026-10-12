import json

def lambda_handler(event, context):
    return {
        "statusCode": 200,
        "body": json.dumps({"status": "healthy", "service": "multi-cloud-event-handler"})
    }

def main(req):
    return json.dumps({"status": "healthy", "service": "multi-cloud-event-handler"})