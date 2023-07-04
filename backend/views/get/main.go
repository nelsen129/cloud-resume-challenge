package main

import (
	"context"
	"errors"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/dynamodb"
	"github.com/aws/aws-sdk-go/service/dynamodb/dynamodbattribute"
	"github.com/aws/aws-xray-sdk-go/xray"
)

type Item struct {
	Quantity int
}

func HandleRequest(ctx context.Context) (int, error) {
	xray.Configure(xray.Config{LogLevel: "trace"})
	sess := session.Must(session.NewSession())
	dynamo := dynamodb.New(sess)
	xray.AWS(dynamo.Client)

	table_name := os.Getenv("TABLE_NAME")
	log.Printf("Attempting to read view-count at stat from %s", table_name)
	result, err := dynamo.GetItemWithContext(ctx, &dynamodb.GetItemInput{
		TableName: &table_name,
		Key: map[string]*dynamodb.AttributeValue{
			"stat": {
				S: aws.String("view-count"),
			},
		},
	})

	if err != nil {
		log.Fatalf("Got error calling GetItem: %s", err)
		return 0, err
	}

	if result.Item == nil {
		msg := "could not find view-count"
		log.Fatalf(msg)
		return 0, errors.New(msg)
	}

	item := Item{}

	err = dynamodbattribute.UnmarshalMap(result.Item, &item)
	if err != nil {
		log.Fatalf("Failed to unmarshal Record, %v", err)
		return 0, err
	}

	return item.Quantity, nil
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
