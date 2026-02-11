/**
 * Fabric Network Configuration
 * Contains connection parameters for Hyperledger Fabric
 */

import path from 'path';

// Base path for crypto materials
const cryptoPath = process.env.FABRIC_CRYPTO_PATH || 
  path.join(__dirname, '..', '..', '..', 'fabric-network', 'crypto-config');

// Organization-specific configuration
interface OrgConfig {
  mspId: string;
  peerEndpoint: string;
  peerHostAlias: string;
  tlsCertPath: string;
  userCertPath: string;
  userKeyDir: string;
}

const orgConfigs: Record<string, OrgConfig> = {
  LawEnforcement: {
    mspId: 'LawEnforcementMSP',
    peerEndpoint: 'localhost:7051',
    peerHostAlias: 'peer0.lawenforcement.evidentia.network',
    tlsCertPath: path.join(cryptoPath, 'peerOrganizations/lawenforcement.evidentia.network/peers/peer0.lawenforcement.evidentia.network/tls/ca.crt'),
    userCertPath: path.join(cryptoPath, 'peerOrganizations/lawenforcement.evidentia.network/users/Admin@lawenforcement.evidentia.network/msp/signcerts/Admin@lawenforcement.evidentia.network-cert.pem'),
    userKeyDir: path.join(cryptoPath, 'peerOrganizations/lawenforcement.evidentia.network/users/Admin@lawenforcement.evidentia.network/msp/keystore')
  },
  ForensicLab: {
    mspId: 'ForensicLabMSP',
    peerEndpoint: 'localhost:9051',
    peerHostAlias: 'peer0.forensiclab.evidentia.network',
    tlsCertPath: path.join(cryptoPath, 'peerOrganizations/forensiclab.evidentia.network/peers/peer0.forensiclab.evidentia.network/tls/ca.crt'),
    userCertPath: path.join(cryptoPath, 'peerOrganizations/forensiclab.evidentia.network/users/Admin@forensiclab.evidentia.network/msp/signcerts/Admin@forensiclab.evidentia.network-cert.pem'),
    userKeyDir: path.join(cryptoPath, 'peerOrganizations/forensiclab.evidentia.network/users/Admin@forensiclab.evidentia.network/msp/keystore')
  },
  Judiciary: {
    mspId: 'JudiciaryMSP',
    peerEndpoint: 'localhost:11051',
    peerHostAlias: 'peer0.judiciary.evidentia.network',
    tlsCertPath: path.join(cryptoPath, 'peerOrganizations/judiciary.evidentia.network/peers/peer0.judiciary.evidentia.network/tls/ca.crt'),
    userCertPath: path.join(cryptoPath, 'peerOrganizations/judiciary.evidentia.network/users/Admin@judiciary.evidentia.network/msp/signcerts/Admin@judiciary.evidentia.network-cert.pem'),
    userKeyDir: path.join(cryptoPath, 'peerOrganizations/judiciary.evidentia.network/users/Admin@judiciary.evidentia.network/msp/keystore')
  }
};

export const fabricConfig = {
  channelName: process.env.FABRIC_CHANNEL_NAME || 'evidence-channel',
  chaincodeName: process.env.FABRIC_CHAINCODE_NAME || 'evidence-coc',
  organization: process.env.FABRIC_ORG || 'LawEnforcement',
  
  getOrgConfig(): OrgConfig {
    const org = this.organization;
    const config = orgConfigs[org];
    if (!config) {
      throw new Error(`Unknown organization: ${org}`);
    }
    return config;
  },

  getAllOrgConfigs(): Record<string, OrgConfig> {
    return orgConfigs;
  }
};

