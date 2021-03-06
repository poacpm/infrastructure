data "archive_file" "lambda-function" {
    type        = "zip"
    source_dir  = "./dynamodb_to_es"
    output_path = "./_zip/dynamodb-to-es.zip"
}

resource "aws_lambda_function" "stream" {
    function_name    = "dynamodb-to-es"
    handler          = "lambda_function.lambda_handler"
    filename         = "${data.archive_file.lambda-function.output_path}"
    source_code_hash = "${data.archive_file.lambda-function.output_base64sha256}"
    memory_size      = 128
    timeout          = 300
    runtime          = "python3.6"
    role             = "${aws_iam_role.lambda.arn}"
    description      = "DynamoDB To ElasticSearch"

    vpc_config {
        subnet_ids = ["${aws_subnet.pub3.id}", "${aws_subnet.pub4.id}"]
        security_group_ids = ["${aws_security_group.allow_all.id}"]
    }
    environment {
        variables = {
            ES_HOST = "${aws_elasticsearch_domain.es.endpoint}"
        }
    }
}


resource "aws_iam_role" "lambda" {
    name = "lambda-dynamodb-trigger"
    assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Sid": ""
        }
    ]
}
EOF
}

# Attach to role
resource "aws_iam_role_policy" "lambda-log-output" {
    role = "${aws_iam_role.lambda.id}"
    name = "lambda-output"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "es:*"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        }
    ]
}
EOF
}
resource "aws_iam_role_policy" "dynamodb-stream" {
    role = "${aws_iam_role.lambda.id}"
    name = "dynamodb-stream"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:DescribeStream",
                "dynamodb:GetRecords",
                "dynamodb:GetShardIterator",
                "dynamodb:ListStreams"
            ],
            "Resource": "${aws_dynamodb_table.package.stream_arn}"
        }
    ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "vpc_permissions" {
    role       = "${aws_iam_role.lambda.name}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

