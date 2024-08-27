package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/grpc-ecosystem/grpc-gateway/v2/runtime"
	servicev1 "github.com/handsOnGrpc/pkg/v1"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

type serviceHello struct {
	servicev1.UnimplementedHelloServiceServer
}

func (s *serviceHello) SayHello(ctx context.Context, req *servicev1.HelloRequest) (*servicev1.HelloResponse, error) {
	log.Println("Message Reqest", req)
	return &servicev1.HelloResponse{ProcessedMessage: fmt.Sprintf("Hello %s, your ID : %d", req.Name, req.Id)}, nil
}
func (s *serviceHello) HelloGetById(ctx context.Context, req *servicev1.HelloById) (*servicev1.HelloResponseById, error) {
	return &servicev1.HelloResponseById{
		Name:        "Harry",
		Id:          req.Id,
		Description: "Hello I'm Harry",
	}, nil
}

func main() {

	ctx := context.Background()

	go func() {
		runGrpcServer(ctx)
	}()
	go func() {
		runGrpcGateway(ctx)
	}()

	quit := make(chan os.Signal)

	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)

	defer cancel()

	select {
	case <-ctx.Done():
		fmt.Println("server shutdown of 2 second")
	}
}

func runGrpcServer(ctx context.Context) {
	lis, err := net.Listen("tcp", ":50051")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	s := grpc.NewServer()
	// opts := []grpc.DialOption{grpc.WithInsecure()}
	servicev1.RegisterHelloServiceServer(s, &serviceHello{})
	if err := s.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}

func runGrpcGateway(ctx context.Context) {
	//run gateway
	mux := runtime.NewServeMux()
	opts := []grpc.DialOption{grpc.WithTransportCredentials(insecure.NewCredentials())}
	// V1 GRPC GATEWAY
	if err := servicev1.RegisterHelloServiceHandlerFromEndpoint(ctx, mux, "localhost:50051", opts); err != nil {
		log.Fatal("failed to start HTTP gateway")
	}

	http.ListenAndServe(":8321", mux)
}
