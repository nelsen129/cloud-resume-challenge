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

type DynamoDBGetItemAPI interface {
	GetItem(ctx context.Context, params *dynamodb.GetItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error)
}

func GetViewCountFromDynamoDBTable(ctx context.Context, api DynamoDBGetItemAPI, table, partitionKey, value string) (int, error) {
	key := map[string]types.AttributeValue{}
	key[partitionKey] = &types.AttributeValueMemberS{Value: value}
	result, err := api.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: &table,
		Key:       key,
	})

	if err != nil {
		return 0, err
	}

	item := Item{}

	err = attributevalue.UnmarshalMap(result.Item, &item)

	if err != nil {
		return 0, err
	}
	return item.Quantity, nil
}

var dynamo *dynamodb.Client
var table_name string

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
	log.Printf("Attempting to read view-count at stat from %s", table_name)

	quantity, err := GetViewCountFromDynamoDBTable(ctx, dynamo, table_name, partition_key, value)

	if err != nil {
		log.Fatalf("Get error calling GetItem: %s", err)
		return 0, err
	}

	log.Printf("Successfully got the view count! View count: %d", quantity)

	return quantity, nil
}

func main() {
	lambda.Start(HandleRequest)
}
