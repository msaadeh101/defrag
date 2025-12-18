# GraphQL for Go Developers
This wiki provides an overview of **GraphQL**, with a particular focus on building GraphQL APIs using Go. It covers core concepts, implementation details, and the advantages of using Go for your GraphQL projects.

## What is GraphQL?
**GraphQL** is a query language for your API and a server-side runtime for executing queries using a type system you define for your data. It was developed by Facebook and open-sourced in 2015. Unlike traditional REST APIs, where you typically hit multiple endpoints to gather all the necessary data, GraphQL allows clients to request exactly the data they need in a single request. This leads to more efficient data fetching and fewer network calls.

## Key Differences from REST

- Single Endpoint: GraphQL APIs typically expose a single endpoint (e.g., /graphql), whereas REST APIs have multiple endpoints (e.g., /users, /products/{id}).

- Client-Driven Data Fetching: Clients specify the shape and depth of the data they require, eliminating over-fetching (getting more data than needed) and under-fetching (needing multiple requests to get complete data).

- Strongly Typed Schema: GraphQL relies on a strongly typed schema that defines all possible data types and operations, providing built-time validation and clear API contracts.

- Versionless by Design: Adding new fields to the schema doesn't break existing clients, promoting continuous evolution without versioning.

## Core GraphQL Concepts

1. **Schema Definition Language (SDL)**

The GraphQL Schema Definition Language (SDL) is a language-agnostic way to define your API's capabilities. It's used to define types, fields, and operations.

- **Defines a custom object type**

```graphql
type User {
  id: ID!
  name: String!
  email: String
  posts: [Post!]!
}

type Post {
  id: ID!
  title: String!
  content: String
  author: User!
}
```

- **Entry points for queries**

```graphql
type Query {
  users: [User!]!
  user(id: ID!): User
  posts: [Post!]!
}
```

- **Entry points for mutations (data modification)**

```graphql
type Mutation {
  createUser(name: String!, email: String): User!
  createPost(title: String!, content: String, authorId: ID!): Post!
}
```

- **Entry points for subscriptions (real-time data)**

```graphql
type Subscription {
  newPost: Post!
}
```

2. **Types**

GraphQL has a powerful type system:

- **Object Types**: The most basic components of a GraphQL schema. They represent a kind of object you can fetch from your service, and what fields they have. (e.g., User, Post).

- **Scalar Types**: Primitive data types that resolve to a single value. GraphQL comes with built-in scalars:
    - `ID`: A unique identifier, often serialized as a string.
    - `String`: A UTF-8 character sequence.
    - `Int`: A signed 32-bit integer.
    - `Float`: A signed double-precision floating-point value.
    - `Boolean`: true or false.

- **Note**: You can also define custom scalar types (e.g., Date, JSON).

- **List Types ([])**: Indicate that a field will return a list of values (e.g., [Post!]!).

- **Non-Null Types (!)**: Indicate that a field must always return a value and cannot be null (e.g., ID!, String!).

- **Input Object Types**: Special object types used as arguments for mutations (e.g., CreateUserInput).

- **Enums**: A special scalar type that restricts the field's value to a specific set of allowed values.

- **Interfaces**: Define a set of fields that multiple object types can implement.

- **Unions**: Allow a field to return one of several object types.

3. **Queries**

Queries are operations used to read data. Clients specify the fields they want from the available types in the schema.

- **Query to fetch all users and their posts**

```graphql
query GetUsersAndPosts {
  users {
    id
    name
    email
    posts {
      title
      content
    }
  }
}
```

- **Query to fetch a specific user by ID**

```graphql
query GetUserById($userId: ID!) {
  user(id: $userId) {
    name
    email
  }
}
# Variables for the above query:
# {
#   "userId": "123"
# }
```

4. **Mutations**

Mutations are operations used to modify data on the server (create, update, delete). They are similar to queries but explicitly declare their intent to change data.

- **Mutation to create a new user**

```graphql
mutation CreateNewUser($name: String!, $email: String) {
  createUser(name: $name, email: $email) {
    id
    name
    email
  }
}
# Variables for the above mutation:
# {
#   "name": "Jane Doe",
#   "email": "jane.doe@example.com"
# }
```

5. **Subscriptions**

Subscriptions are operations that allow clients to receive real-time updates from the server when specific events occur. They are typically implemented over WebSockets.

- **Subscription to get new posts as they are created**

```graphql
subscription OnNewPost {
  newPost {
    id
    title
    author {
      name
    }
  }
}
```

6. **Resolvers**

For every field in your schema, there needs to be a resolver function. A **resolver** is a function that's responsible for fetching the data for its corresponding field. When a query comes in, the GraphQL server executes the relevant resolvers to construct the response.

## Why Use Go for GraphQL?
Go is an excellent choice for building GraphQL APIs due to its:

**Performance**: Go's compilation to machine code and efficient concurrency model (goroutines and channels) make it incredibly fast, capable of handling a high volume of requests.

**Concurrency**: GraphQL APIs often involve fetching data from multiple sources concurrently. Go's native goroutines and channels make managing these concurrent operations straightforward and highly performant.

**Strong Typing**: Go's static typing aligns well with GraphQL's strong type system, providing compile-time safety and reducing runtime errors.

**Simplicity & Readability**: Go's clean syntax and opinionated design lead to maintainable and readable code, which is crucial for complex API schemas.

**Developer Experience**: Tools like go fmt and go vet, along with fast compilation times, contribute to a productive development environment.

**Small Footprint**: Go binaries are statically linked, resulting in small, self-contained executables that are easy to deploy.

## Building a GraphQL Server in Go
There are several popular libraries for building GraphQL servers in Go. Two prominent ones are:

1. `graphql-go/graphql`: A more low-level, schema-first library where you define your schema directly in Go code. It offers fine-grained control.

2. `99designs/gqlgen`: A code-generation first approach. You define your schema using GraphQL SDL, and gqlgen generates the Go types and resolver interfaces for you, simplifying boilerplate and ensuring type safety. This is often preferred for larger projects.

We'll focus on a simple example using graphql-go/graphql for clarity, but gqlgen is highly recommended for real-world applications.

Basic Setup with `graphql-go/graphql`

Let's create a simple API to fetch and create Product data.

1. Initialize Go Module

```bash
mkdir go-graphql-server
cd go-graphql-server
go mod init go-graphql-server
go get github.com/graphql-go/graphql
go get github.com/graphql-go/handler # For easier HTTP handling
```

2. Define the Schema and Resolvers

Create a main.go file.

```go
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strconv"

	"github.com/graphql-go/graphql"
	"github.com/graphql-go/handler"
)

// Product represents our data model
type Product struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Price       float64 `json:"price"`
}

// In-memory "database" for demonstration
var products = []Product{
	{ID: "1", Name: "Laptop", Description: "Powerful computing", Price: 1200.00},
	{ID: "2", Name: "Mouse", Description: "Ergonomic design", Price: 25.00},
}

// Define the GraphQL Product object type
var productType = graphql.NewObject(
	graphql.ObjectConfig{
		Name: "Product",
		Fields: graphql.Fields{
			"id": &graphql.Field{
				Type: graphql.NewNonNull(graphql.ID),
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					if product, ok := p.Source.(Product); ok {
						return product.ID, nil
					}
					return nil, nil
				},
			},
			"name": &graphql.Field{
				Type: graphql.NewNonNull(graphql.String),
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					if product, ok := p.Source.(Product); ok {
						return product.Name, nil
					}
					return nil, nil
				},
			},
			"description": &graphql.Field{
				Type: graphql.String,
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					if product, ok := p.Source.(Product); ok {
						return product.Description, nil
					}
					return nil, nil
				},
			},
			"price": &graphql.Field{
				Type: graphql.NewNonNull(graphql.Float),
				Resolve: func(p graphql.ResolveParams) (interface{}, error) {
					if product, ok := p.Source.(Product); ok {
						return product.Price, nil
					}
					return nil, nil
				},
			},
		},
	},
)

// Define the Root Query type
var rootQuery = graphql.NewObject(graphql.ObjectConfig{
	Name: "RootQuery",
	Fields: graphql.Fields{
		"product": &graphql.Field{
			Type:        productType,
			Description: "Get single product by ID",
			Args: graphql.FieldConfigArgument{
				"id": &graphql.ArgumentConfig{
					Type: graphql.NewNonNull(graphql.ID),
				},
			},
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				id, ok := p.Args["id"].(string)
				if ok {
					for _, product := range products {
						if product.ID == id {
							return product, nil
						}
					}
				}
				return nil, nil
			},
		},
		"products": &graphql.Field{
			Type:        graphql.NewList(productType),
			Description: "Get all products",
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				return products, nil
			},
		},
	},
})

// Define the Root Mutation type
var rootMutation = graphql.NewObject(graphql.ObjectConfig{
	Name: "RootMutation",
	Fields: graphql.Fields{
		"createProduct": &graphql.Field{
			Type:        productType,
			Description: "Create new product",
			Args: graphql.FieldConfigArgument{
				"name": &graphql.ArgumentConfig{
					Type: graphql.NewNonNull(graphql.String),
				},
				"description": &graphql.ArgumentConfig{
					Type: graphql.String,
				},
				"price": &graphql.ArgumentConfig{
					Type: graphql.NewNonNull(graphql.Float),
				},
			},
			Resolve: func(p graphql.ResolveParams) (interface{}, error) {
				name, _ := p.Args["name"].(string)
				description, _ := p.Args["description"].(string)
				price, _ := p.Args["price"].(float64)

				newID := strconv.Itoa(len(products) + 1) // Simple ID generation
				newProduct := Product{
					ID:          newID,
					Name:        name,
					Description: description,
					Price:       price,
				}
				products = append(products, newProduct)
				return newProduct, nil
			},
		},
	},
})

// Create the GraphQL Schema
var schema, _ = graphql.NewSchema(
	graphql.SchemaConfig{
		Query:    rootQuery,
		Mutation: rootMutation,
	},
)

func executeQuery(query string, schema graphql.Schema) *graphql.Result {
	result := graphql.Do(graphql.Params{
		Schema:        schema,
		RequestString: query,
		// If you have a context (e.g., for authentication), pass it here:
		// Context: context.WithValue(context.Background(), "auth", "your-token"),
	})
	if len(result.Errors) > 0 {
		log.Printf("wrong result, errors: %v", result.Errors)
	}
	return result
}

func main() {
	// Create a GraphQL HTTP handler
	h := handler.New(&handler.Config{
		Schema:     &schema,
		Pretty:     true, // Pretty print JSON response
		GraphiQL:   true, // Enable GraphiQL UI for testing
		Playground: true, // Enable GraphQL Playground UI (modern alternative to GraphiQL)
	})

	// Register the GraphQL endpoint
	http.Handle("/graphql", h)

	// Start the server
	port := ":8080"
	log.Printf("GraphQL server running on http://localhost%s/graphql", port)
	log.Fatal(http.ListenAndServe(port, nil))
}
```

3. Run the Server

```bash
go run main.go
```

Now, open your browser and navigate to http://localhost:8080/graphql. You should see the GraphiQL or GraphQL Playground interface, where you can test your queries and mutations!

Example Query:

```graphql
query {
  products {
    id
    name
    price
  }
}
```

Example Mutation:

```graphql
mutation {
  createProduct(name: "Keyboard", description: "Mechanical keyboard", price: 75.00) {
    id
    name
    price
  }
}
```

## Tools and Ecosystem

1. **GraphiQL / GraphQL Playground**

These are in-browser IDEs for GraphQL. They provide:

Query Editor: Write and execute queries, mutations, and subscriptions.

Schema Explorer: Browse your API's schema, understand types, fields, and arguments.

Documentation: Auto-generated documentation based on your schema.

They are invaluable for developing and testing GraphQL APIs.

2. **Client-Side Libraries**

While GraphQL is backend-agnostic, clients benefit from libraries that simplify interacting with GraphQL APIs. Popular choices include:

**Apollo Client**: A comprehensive, feature-rich GraphQL client for JavaScript/TypeScript, popular in React/Vue/Angular applications.

**Relay**: Another powerful JavaScript client, also from Facebook, often chosen for large-scale applications with complex data requirements.

**github.com/machinebox/graphql (Go Client)**: A simple and robust Go client library for consuming GraphQL APIs.

## Conclusion

GraphQL offers a powerful and flexible approach to API design, empowering clients to fetch precisely what they need. Go's performance, strong typing, and concurrency features make it an excellent language for building robust and scalable GraphQL servers. By leveraging libraries like `graphql-go/graphql` or 99designs/gqlgen, Go developers can efficiently create and manage GraphQL APIs that cater to modern application needs.

