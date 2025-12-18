package protobuf

import (
	"fmt"
	"log"

	pb "./pb" // Import the generated protobuf package
	"google.golang.org/protobuf/proto"
)

func main() {
	// Create a new Person, pointing to the address of &pb
	person := &pb.Person{
		Name:  "John Doe",
		Age:   30,
		Email: "john.doe@example.com",
		PhoneNumbers: []string{
			"555-1234",
			"555-5678",
		},
		Gender: pb.Person_MALE,
	}

	// Serialize to binary format: Go struct -> binary bytes
	data, err := proto.Marshal(person)
	// Now 'data' is a []byte containing the binary represenation
	if err != nil {
		log.Fatalf("Failed to marshal person: %v", err)
	}

	fmt.Printf("Serialized data size: %d bytes\n", len(data))
	fmt.Printf("Binary data: %x\n", data)

	// Deserialize back to Person struct
	newPerson := &pb.Person{}
	err = proto.Unmarshal(data, newPerson)
	if err != nil {
		log.Fatalf("Failed to unmarshal person: %v", err)
	}

	// Print the deserialized data
	fmt.Println("\nDeserialized Person:")
	fmt.Printf("Name: %s\n", newPerson.GetName())
	fmt.Printf("Age: %d\n", newPerson.GetAge())
	fmt.Printf("Email: %s\n", newPerson.GetEmail())
	fmt.Printf("Phone numbers: %v\n", newPerson.GetPhoneNumbers())
	fmt.Printf("Gender: %v\n", newPerson.GetGender())

	// Create an AddressBook with multiple people
	addressBook := &pb.AddressBook{
		People: []*pb.Person{
			person,
			{
				Name:   "Jane Smith",
				Age:    25,
				Email:  "jane.smith@example.com",
				Gender: pb.Person_FEMALE,
			},
		},
	}

	// Serialize the address book
	bookData, err := proto.Marshal(addressBook)
	if err != nil {
		log.Fatalf("Failed to marshal address book: %v", err)
	}

	fmt.Printf("\nAddress book serialized size: %d bytes\n", len(bookData))

	// Deserialize the address book
	newBook := &pb.AddressBook{}
	err = proto.Unmarshal(bookData, newBook)
	if err != nil {
		log.Fatalf("Failed to unmarshal address book: %v", err)
	}

	fmt.Printf("\nAddress book contains %d people:\n", len(newBook.GetPeople()))
	for i, p := range newBook.GetPeople() {
		fmt.Printf("%d. %s (%d years old)\n", i+1, p.GetName(), p.GetAge())
	}
}
