from fastapi import FastAPI
from mangum import Mangum

app = FastAPI()

@app.get("/")
def root():
    return {"message": "Hello From AWS Lambda via API Gateway Deployed via Terraform!"}

@app.get("/api/v1/users")
def get_users():
    return {"message": "Users!"}

# Lambda entry point
handler = Mangum(app)
