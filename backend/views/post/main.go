package main

import (
	"context"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
	"github.com/aws/aws-xray-sdk-go/instrumentation/awsv2"
	"github.com/aws/aws-xray-sdk-go/xray"
)

type Item struct {
	Quantity int
}

type DynamoDBUpdateItemAPI interface {
	UpdateItem(ctx context.Context, params *dynamodb.UpdateItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.UpdateItemOutput, error)
}

var dynamo *dynamodb.Client
var table_name string

func UpdateViewCountInDynamoDBTable(ctx context.Context, api DynamoDBUpdateItemAPI, table, partitionKey, value, update_expression string) (int, error) {
	key := map[string]types.AttributeValue{}
	key[partitionKey] = &types.AttributeValueMemberS{Value: value}
	result, err := api.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName: &table,
		Key:       key,
		ExpressionAttributeValues: map[string]types.AttributeValue{
			":inc": &types.AttributeValueMemberN{Value: "1"},
		},
		UpdateExpression: &update_expression,
		ReturnValues:     "UPDATED_NEW",
	})

	if err != nil {
		return 0, err
	}

	item := Item{}

	err = attributevalue.UnmarshalMap(result.Attributes, &item)

	if err != nil {
		return 0, err
	}
	return item.Quantity, nil
}

func init() {
	xray.Configure(xray.Config{
		DaemonAddr:     "127.0.0.1:2000", // default
		ServiceVersion: "1.2.3",
	})
	cfg, err := config.LoadDefaultConfig(context.TODO())
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
		return
	}
	awsv2.AWSV2Instrumentor(&cfg.APIOptions)
	dynamo = dynamodb.NewFromConfig(cfg)
	table_name = os.Getenv("TABLE_NAME")
}

func HandleRequest(ctx context.Context) (int, error) {
	partition_key := "stat"
	value := "view-count"
	update_expression := "ADD Quantity :inc"
	log.Printf("Attempting to update view-count at stat from %s", table_name)

	quantity, err := UpdateViewCountInDynamoDBTable(ctx, dynamo, table_name, partition_key, value, update_expression)

	if err != nil {
		log.Fatalf("Got error calling UpdateItem: %s", err)
		return 0, err
	}

	log.Printf("Successfully updated the view count! New view count: %d", quantity)

	return quantity, nil
}

func main() {
	lambda.Start(HandleRequest)
}
