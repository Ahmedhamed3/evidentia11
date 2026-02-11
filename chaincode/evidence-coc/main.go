// Copyright Evidentia Chain-of-Custody System
// Main entry point for the Evidence Chain-of-Custody Chaincode

package main

import (
	"log"
	"os"

	"github.com/hyperledger/fabric-chaincode-go/v2/shim"
	"github.com/hyperledger/fabric-contract-api-go/v2/contractapi"
)

func main() {
	evidenceChaincode, err := contractapi.NewChaincode(&EvidenceContract{})
	if err != nil {
		log.Panicf("Error creating evidence-coc chaincode: %v", err)
	}

	// Check if running in CCaaS (Chaincode-as-a-Service) mode
	ccid := os.Getenv("CHAINCODE_ID")
	ccaddr := os.Getenv("CHAINCODE_SERVER_ADDRESS")

	if ccid != "" && ccaddr != "" {
		// CCaaS mode - start as a server
		log.Printf("Starting chaincode as a service: ID=%s, Address=%s", ccid, ccaddr)
		
		server := &shim.ChaincodeServer{
			CCID:    ccid,
			Address: ccaddr,
			CC:      evidenceChaincode,
			TLSProps: shim.TLSProperties{
				Disabled: true,
			},
		}

		if err := server.Start(); err != nil {
			log.Panicf("Error starting chaincode server: %v", err)
		}
	} else {
		// Traditional mode - connect to peer
		if err := evidenceChaincode.Start(); err != nil {
			log.Panicf("Error starting evidence-coc chaincode: %v", err)
		}
	}
}

