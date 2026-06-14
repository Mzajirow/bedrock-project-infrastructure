# IAM User
resource "aws_iam_user" "dev_view" {
  name = "bedrock-dev-view"
  tags = { Project = "karatu-2025-capstone" }
}

# Attach ReadOnlyAccess managed policy
resource "aws_iam_user_policy_attachment" "dev_readonly" {
  user       = aws_iam_user.dev_view.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Allow dev user to upload to assets bucket
resource "aws_iam_user_policy" "dev_s3_upload" {
  name = "bedrock-dev-s3-upload"
  user = aws_iam_user.dev_view.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:PutObject"
      Resource = "arn:aws:s3:::bedrock-assets-4910/*"
    }]
  })
}

# Generate access keys
resource "aws_iam_access_key" "dev_view" {
  user = aws_iam_user.dev_view.name
}

# Enable console access with a password
resource "aws_iam_user_login_profile" "dev_view" {
  user                    = aws_iam_user.dev_view.name
  password_reset_required = false
}