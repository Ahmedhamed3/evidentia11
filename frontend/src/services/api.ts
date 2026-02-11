import axios, { AxiosInstance, AxiosError } from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:3001';

// Create axios instance
const api: AxiosInstance = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor to add auth token
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => response,
  (error: AxiosError) => {
    if (error.response?.status === 401) {
      // Clear auth state on 401
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

// API interfaces
export interface LoginResponse {
  success: boolean;
  data?: {
    token: string;
    user: User;
    expiresIn: string;
  };
  error?: string;
}

export interface User {
  id: string;
  username: string;
  organization: string;
  mspId: string;
  role: string;
  commonName: string;
}

export interface Evidence {
  id: string;
  caseId: string;
  ipfsHash: string;
  evidenceHash: string;
  encryptionKeyId: string;
  metadata: EvidenceMetadata;
  status: string;
  currentCustodian: string;
  currentOrg: string;
  registeredBy: string;
  createdAt: number;
  updatedAt: number;
  tags: string[];
  integrityVerified: boolean;
  lastVerifiedAt: number;
}

export interface EvidenceMetadata {
  name: string;
  type: string;
  size: number;
  mimeType: string;
  sourceDevice: string;
  acquisitionDate: number;
  acquisitionTool: string;
  acquisitionNotes: string;
  location: string;
  examinerNotes: string;
}

export interface CustodyEvent {
  eventId: string;
  evidenceId: string;
  eventType: string;
  fromEntity: string;
  fromOrg: string;
  toEntity: string;
  toOrg: string;
  reason: string;
  details: string;
  timestamp: number;
  performedBy: string;
  performerOrg: string;
  txId: string;
  verified: boolean;
}

export interface AuditReportData {
  reportId: string;
  evidenceId: string;
  evidence: Evidence;
  custodyChain: CustodyEvent[];
  analysisRecords: any[];
  judicialReviews: any[];
  generatedAt: number;
  generatedBy: string;
  integrityHash: string;
  verified: boolean;
}

// Auth API
export const authAPI = {
  login: (username: string, password: string) =>
    api.post<LoginResponse>('/api/auth/login', { username, password }),
  
  getMe: () =>
    api.get('/api/auth/me'),
  
  getUsers: () =>
    api.get('/api/auth/users'),
};

// Evidence API
export const evidenceAPI = {
  list: (params?: { caseId?: string; status?: string }) =>
    api.get('/api/evidence', { params }),
  
  get: (id: string) =>
    api.get(`/api/evidence/${id}`),
  
  register: (formData: FormData) =>
    api.post('/api/evidence', formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    }),
  
  transfer: (id: string, data: { toEntityId: string; toOrgMSP: string; reason: string }) =>
    api.post(`/api/evidence/${id}/transfer`, data),
  
  recordAnalysis: (id: string, data: { toolUsed: string; toolVersion?: string; findings: string; artifacts?: string[]; methodology?: string }) =>
    api.post(`/api/evidence/${id}/analysis`, data),
  
  submitForReview: (id: string, data: { caseNotes?: string }) =>
    api.post(`/api/evidence/${id}/review`, data),
  
  recordDecision: (id: string, data: { reviewId: string; decision: 'ADMITTED' | 'REJECTED'; decisionReason?: string; courtReference?: string }) =>
    api.post(`/api/evidence/${id}/decision`, data),
  
  addTag: (id: string, tag: string) =>
    api.post(`/api/evidence/${id}/tag`, { tag }),
  
  verify: (id: string, hash: string) =>
    api.post(`/api/evidence/${id}/verify`, { hash }),
  
  getHistory: (id: string) =>
    api.get(`/api/evidence/${id}/history`),
  
  getAnalysis: (id: string) =>
    api.get(`/api/evidence/${id}/analysis`),
};

// Audit API
export const auditAPI = {
  getReport: (evidenceId: string) =>
    api.get(`/api/audit/report/${evidenceId}`),
  
  getCustodyChain: (evidenceId: string) =>
    api.get(`/api/audit/custody-chain/${evidenceId}`),
  
  getTimeline: (evidenceId: string) =>
    api.get(`/api/audit/timeline/${evidenceId}`),
  
  getCaseAudit: (caseId: string) =>
    api.get(`/api/audit/case/${caseId}`),
  
  exportReport: (evidenceId: string, format: 'json' | 'text' = 'json') =>
    api.get(`/api/audit/export/${evidenceId}`, { 
      params: { format },
      responseType: format === 'json' ? 'json' : 'blob'
    }),
};

export default api;

