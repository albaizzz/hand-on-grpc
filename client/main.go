package main

import (
	"context"
	"log"

	servicev1 "github.com/handsOnGrpc/pkg/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

func main() {
	opts := []grpc.DialOption{grpc.WithTransportCredentials(insecure.NewCredentials())}
	conn, err := grpc.Dial("localhost:50051", opts...)
	if err != nil {
		log.Fatalf("did not connect: %v", err)
	}
	defer conn.Close()
	client := servicev1.NewHelloServiceClient(conn)

	req := &servicev1.HelloRequest{Id: 1, Name: "Bryan OCorner", Description: "Tech Brosss!!"}
	res, err := client.SayHello(context.Background(), req)
	if err != nil {
		log.Fatalf("could not greet: %v", err)
	}
	log.Println("#########")
	log.Printf("Greeting: %s", res.ProcessedMessage)
	log.Println("#########")
}
