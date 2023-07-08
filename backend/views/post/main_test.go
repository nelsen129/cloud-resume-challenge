package main

import (
	"context"
	"strconv"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

type mockUpdateItemAPI func(ctx context.Context, params *dynamodb.UpdateItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.UpdateItemOutput, error)

func (m mockUpdateItemAPI) UpdateItem(ctx context.Context, params *dynamodb.UpdateItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.UpdateItemOutput, error) {
	return m(ctx, params, optFns...)
}

func TestUpdateItemInDynamoDB(t *testing.T) {
	cases := []struct {
		client        func(t *testing.T) DynamoDBUpdateItemAPI
		table         string
		partition_key string
		value         string
		expression    string
		expect        int
	}{
		{
			client: func(t *testing.T) DynamoDBUpdateItemAPI {
				return mockUpdateItemAPI(func(ctx context.Context, params *dynamodb.UpdateItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.UpdateItemOutput, error) {
					t.Helper()
					if params.TableName == nil {
						t.Fatal("expect TableName to not be nil")
					}
					if params.Key == nil {
						t.Fatal("expect Key to not be nil")
					}
					if params.UpdateExpression == nil {
						t.Fatal("expect UpdateExpression to not be nil")
					}

					return &dynamodb.UpdateItemOutput{Attributes: map[string]types.AttributeValue{
						"Quantity": &types.AttributeValueMemberN{Value: "1"},
					}}, nil
				})
			},
			table:         "fooTable",
			partition_key: "barPK",
			value:         "bazValue",
			expression:    "ADD Quantity :inc",
			expect:        1,
		},
	}

	for i, tt := range cases {
		t.Run(strconv.Itoa(i), func(t *testing.T) {
			ctx := context.TODO()
			content, err := UpdateViewCountInDynamoDBTable(ctx, tt.client(t), tt.table, tt.partition_key, tt.value, tt.expression)
			if err != nil {
				t.Fatalf("expect no error, got %v", err)
			}
			if e, a := tt.expect, content; e != a {
				t.Errorf("expect %v, got %v", e, a)
			}
		})
	}
}
