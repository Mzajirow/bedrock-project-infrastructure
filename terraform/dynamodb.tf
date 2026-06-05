resource "aws_dynamodb_table" "retail_carts" {
  name         = "bedrock-retail-carts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }

  tags = { Project = "karatu-2025-capstone" }
}