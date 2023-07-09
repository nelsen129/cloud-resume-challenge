package main

import (
	"context"
	"strconv"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

type mockGetItemAPI func(ctx context.Context, params *dynamodb.GetItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error)

func (m mockGetItemAPI) GetItem(ctx context.Context, params *dynamodb.GetItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error) {
	return m(ctx, params, optFns...)
}

func TestGetItemInDynamoDB(t *testing.T) {
	cases := []struct {
		client        func(t *testing.T) DynamoDBGetItemAPI
		table         string
		partition_key string
		value         string
		expect        int
	}{
		{
			client: func(t *testing.T) DynamoDBGetItemAPI {
				return mockGetItemAPI(func(ctx context.Context, params *dynamodb.GetItemInput, optFns ...func(*dynamodb.Options)) (*dynamodb.GetItemOutput, error) {
					t.Helper()
					if params.TableName == nil {
						t.Fatal("expect TableName to not be nil")
					}
					if params.Key == nil {
						t.Fatal("expect Key to not be nil")
					}

					return &dynamodb.GetItemOutput{Item: map[string]types.AttributeValue{
						"Quantity": &types.AttributeValueMemberN{Value: "1"},
					}}, nil
				})
			},
			table:         "fooTable",
			partition_key: "barPK",
			value:         "bazValue",
			expect:        1,
		},
	}

	for i, tt := range cases {
		t.Run(strconv.Itoa(i), func(t *testing.T) {
			ctx := context.TODO()
			content, err := GetViewCountFromDynamoDBTable(ctx, tt.client(t), tt.table, tt.partition_key, tt.value)
			if err != nil {
				t.Fatalf("expect no error, got %v", err)
			}
			if e, a := tt.expect, content; e != a {
				t.Errorf("expect %v, got %v", e, a)
			}
		})
	}
}
