package main

import (
	"context"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/aws/aws-xray-sdk-go/instrumentation/awsv2"
	"github.com/aws/aws-xray-sdk-go/xray"
)

type Item struct {
	Quantity int
}

func HandleRequest(ctx context.Context) error {
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
		return err
	}
	awsv2.AWSV2Instrumentor(&cfg.APIOptions)
	dynamo := dynamodb.NewFromConfig(cfg)

	table_name := os.Getenv("TABLE_NAME")
	update_expression := "ADD Quantity :inc"
	log.Printf("Attempting to update view-count at stat from %s", table_name)
	result, err := dynamo.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName: &table_name,
		Key: map[string]types.AttributeValue{
			"stat": &types.AttributeValueMemberS{Value: "view-count"},
		},
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":inc": &types.AttributeValueMemberN{Value: "1"},
		},
		UpdateExpression: &update_expression,
	})

	if err != nil {
		log.Fatalf("Got error calling UpdateItem: %s", err)
		return err
	}

	log.Printf("Successfully updated the view count!")
	log.Printf("Output attributes: %T", result.Attributes)

	return nil
}

func init() {
	xray.Configure(xray.Config{
		DaemonAddr:     "127.0.0.1:2000", // default
		ServiceVersion: "1.2.3",
	})
}

func main() {
	lambda.Start(HandleRequest)
}
