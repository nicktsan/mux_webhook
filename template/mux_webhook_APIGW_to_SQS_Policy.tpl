{
  "Version" : "2012-10-17",
  "Statement" : [
    {
      "Effect" : "Allow",
      "Action" : [
        "sqs:SendMessage",
        "sqs:ListQueues"
      ],
      "Resource" : "${sqsarn}"
    }
  ]
}