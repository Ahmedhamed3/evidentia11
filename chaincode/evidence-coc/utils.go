// Copyright Evidentia Chain-of-Custody System
// Utility functions for the chaincode

package main

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"time"
)

// GenerateID generates a unique ID based on prefix, timestamp, and optional data
func GenerateID(prefix string, additionalData ...string) string {
	timestamp := time.Now().UnixNano()
	data := fmt.Sprintf("%s-%d", prefix, timestamp)
	for _, d := range additionalData {
		data += "-" + d
	}
	hash := sha256.Sum256([]byte(data))
	return fmt.Sprintf("%s-%s", prefix, hex.EncodeToString(hash[:8]))
}

// HashData creates a SHA-256 hash of the provided data
func HashData(data []byte) string {
	hash := sha256.Sum256(data)
	return hex.EncodeToString(hash[:])
}

// HashJSON creates a SHA-256 hash of a JSON-serializable object
func HashJSON(obj interface{}) (string, error) {
	data, err := json.Marshal(obj)
	if err != nil {
		return "", err
	}
	return HashData(data), nil
}

// ValidateHash validates that a provided hash matches expected format
func ValidateHash(hash string) bool {
	// SHA-256 produces 64 hex characters
	if len(hash) != 64 {
		return false
	}
	for _, c := range hash {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
			return false
		}
	}
	return true
}

// ValidateIPFSCID validates an IPFS CID format (basic validation)
// Design Decision: Supporting both CIDv0 (Qm...) and CIDv1 (ba...)
func ValidateIPFSCID(cid string) bool {
	if len(cid) < 46 {
		return false
	}
	// CIDv0 starts with "Qm" and is 46 characters
	if len(cid) == 46 && cid[:2] == "Qm" {
		return true
	}
	// CIDv1 starts with "ba" (for base32) or "b" (for other bases)
	if cid[0] == 'b' {
		return true
	}
	return false
}

// FormatTimestamp formats a Unix timestamp as ISO 8601 string
func FormatTimestamp(timestamp int64) string {
	return time.Unix(timestamp, 0).UTC().Format(time.RFC3339)
}

// ParseTimestamp parses an ISO 8601 string to Unix timestamp
func ParseTimestamp(s string) (int64, error) {
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return 0, err
	}
	return t.Unix(), nil
}

// Min returns the minimum of two int64 values
func Min(a, b int64) int64 {
	if a < b {
		return a
	}
	return b
}

// Max returns the maximum of two int64 values
func Max(a, b int64) int64 {
	if a > b {
		return a
	}
	return b
}

// Contains checks if a string slice contains a specific value
func Contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}

// RemoveFromSlice removes an item from a string slice
func RemoveFromSlice(slice []string, item string) []string {
	result := make([]string, 0, len(slice))
	for _, s := range slice {
		if s != item {
			result = append(result, s)
		}
	}
	return result
}

// TruncateString truncates a string to maxLen characters, adding "..." if truncated
func TruncateString(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	if maxLen <= 3 {
		return s[:maxLen]
	}
	return s[:maxLen-3] + "..."
}

// SanitizeInput performs basic input sanitization
func SanitizeInput(input string, maxLen int) string {
	// Remove null bytes
	result := ""
	for _, c := range input {
		if c != 0 {
			result += string(c)
		}
	}
	// Truncate if needed
	if len(result) > maxLen {
		result = result[:maxLen]
	}
	return result
}

