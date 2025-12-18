# Protobuf Go Example Setup

## What is Protobuf

**Protobuf** (*Protocol Buffers*) is a way to define and exchange data between services. It is like JSON or XML but *smaller, faster, and strongly typed*.

When you are developing microservices, APIs, or gRPC in Go, you'll use Protobuf. Instead of manually writing structs and serialization code, you:
1. Write a `.proto` file schema.
2. Run the `protoc` compiler.
3. Get generated Go code (`.pg.go`) with ready to use structs and methods.
4. Use these structs in your Go application!

## Prerequisites

1. Install Protocol Buffer Compiler (protoc)

```bash
# On macOS with Homebrew
brew install protobuf

# On Ubuntu/Debian
sudo apt install protobuf-compiler
```

2. Install Go Protocol Buffer Plugin

```bash
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
```

3. Initialize Go Module 

```bash
mkdir protobuf
cd protobuf
go mod init protobuf
go get google.golang.org/protobuf
```

## File Structure

```txt
protobuf/
├── go.mod
├── person.proto
├── main.go
└── pb/
    └── person.pb.go (generated)
```

## Steps to Run

1. Create the proto file `person.proto` with definition.
2. Generate Go code from proto file

```bash
mkdir pb
protoc --go_out=./pb --go_opts=paths=source_relative person.proto
```

3. Run the example

```bash
go run main.go
```

## Output (Expected)

```txt
Serialized data size: 47 bytes
Binary data: 0a084a6f686e20446f651e1a15...

Deserialized Person:
Name: John Doe
Age: 30
Email: john.doe@example.com
Phone numbers: [555-1234 555-5678]
Gender: MALE

Address book serialized size: 73 bytes

Address book contains 2 people:
1. John Doe (30 years old)
2. Jane Smith (25 years old)
```

## Key Points


- **Message Definition**: The Person message with various field types (`string`, `int32`, `repeated string`, `enum`).
- **Nested Messages**: AddressBook containing multiple Person messages.
- **Serialization**: Converting Go structs to binary data using proto.Marshal().
- **Deserializtion**: Converting binary data back to Go structs using proto.Unmarshal().
- **Field Numbers**: Each field has a unique number used in the binary format. Field numbers are crucial for binary consistency.
- **Getters**: Protobuf generates getter methods like `GetName()`, `GetAge()` for safe field access.
- **Repeated Fields**: Use repeated keyword for arrays/slices.
- **Enums**: Define enumerated types with messages. Gender enumeration with predefined values.
- **Zero Values**: Missing fields return zero values (empty string, 0, false, etc.)
- **Backwards Compatibility**: You can add new fields without breaking existing code.

## Important Generated Components

1. **Enum Types**: `Person_Gender` with constants `Person_UNKNOWN`, `Person_MALE`, `Person_FEMALE`.

2. **Struct Definitions**:
- `Person` struct with all your fields as Go struct fields.
- `AddressBook` struct containing a slice of `*Person`.

3. **Getter Methods**: Safe accessor methods like:
- `GetName() string` - returns empty string if nil.
- `GetAge() int32` - returns 0 if nil.
- `GetPhoneNumbers() []string` - returns nil if empty.

4. **Protocol Buffer Interface Methods**:
- `Reset()` - resets the struct to empty state.
- `String()` - string representation.
- `ProtoMessage()` - marker interface.
- `ProtoReflect()` - reflection support.

5. **Binary Schema**: The `file_person_proto_rawDesc` contains the compressed binary schema definition.

**Key Benefits**:
- **Null Safety**: Getters handle nil pointers gracefully.
- **JSON Tags**: Automatic JSON marshaling support with `json:"field_name,omitempty"`
- **Wire Format**: Efficient binary serialization/deserialization.
- **Reflection**: Runtime introspection capabilities.
- **Backwards Compatibility**: Can evolve schema without breaking existing code.