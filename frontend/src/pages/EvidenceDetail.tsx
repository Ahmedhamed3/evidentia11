import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { evidenceAPI, auditAPI, Evidence, CustodyEvent } from '../services/api';
import { useAuth } from '../context/AuthContext';
import toast from 'react-hot-toast';
import {
  ArrowLeftIcon,
  ShieldCheckIcon,
  ClockIcon,
  DocumentTextIcon,
  ArrowsRightLeftIcon,
  BeakerIcon,
  ScaleIcon,
  TagIcon,
  CheckCircleIcon,
  XCircleIcon,
} from '@heroicons/react/24/outline';

const EvidenceDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const { user } = useAuth();
  const [evidence, setEvidence] = useState<Evidence | null>(null);
  const [history, setHistory] = useState<CustodyEvent[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('details');
  const [registrationTxId, setRegistrationTxId] = useState<string | null>(null);
  
  // Modal states
  const [showTransferModal, setShowTransferModal] = useState(false);
  const [showAnalysisModal, setShowAnalysisModal] = useState(false);
  const [showReviewModal, setShowReviewModal] = useState(false);

  useEffect(() => {
    const fetchData = async () => {
      if (!id) return;
      
      try {
        const [evidenceRes, historyRes] = await Promise.all([
          evidenceAPI.get(id),
          evidenceAPI.getHistory(id),
        ]);
        
        if (evidenceRes.data.success) {
          setEvidence(evidenceRes.data.data);
        }
        if (historyRes.data.success) {
          const historyData = historyRes.data.data || [];
          setHistory(historyData);
          // Get the registration transaction ID (first event, which is typically the registration)
          if (historyData.length > 0) {
            // Sort by timestamp to get the earliest event (registration)
            const sortedHistory = [...historyData].sort((a: CustodyEvent, b: CustodyEvent) => a.timestamp - b.timestamp);
            const registrationEvent = sortedHistory[0];
            if (registrationEvent && registrationEvent.txId) {
              setRegistrationTxId(registrationEvent.txId);
            }
          }
        }
      } catch (error) {
        console.error('Failed to fetch evidence:', error);
        toast.error('Failed to load evidence details');
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, [id]);

  const formatDate = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleString();
  };

  const formatSize = (bytes: number) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    return (bytes / (1024 * 1024 * 1024)).toFixed(1) + ' GB';
  };

  // Format X.509 identity or user ID to readable name
  const formatCustodian = (custodian: string, org?: string) => {
    // Check if it's a simple user ID
    const userIdMap: Record<string, string> = {
      'collector-le-001': 'Officer Ahmed',
      'supervisor-le-001': 'Sergeant Mohamed',
      'analyst-fl-001': 'Dr. Fatima',
      'supervisor-fl-001': 'Dr. Khaled',
      'counsel-jd-001': 'Attorney Ali',
      'judge-jd-001': 'Judge Sara',
      'auditor-jd-001': 'Auditor Omar',
    };
    
    if (userIdMap[custodian]) {
      return userIdMap[custodian];
    }
    
    // Try to decode X.509 identity (base64 encoded)
    try {
      if (custodian.length > 50) {
        const decoded = atob(custodian);
        // Extract CN (Common Name) from the decoded string
        const cnMatch = decoded.match(/CN=([^,]+)/);
        if (cnMatch) {
          return cnMatch[1].replace('@', ' @ ');
        }
      }
    } catch {
      // Not base64, return truncated
    }
    
    // Return truncated if too long
    if (custodian.length > 30) {
      return custodian.substring(0, 15) + '...' + custodian.substring(custodian.length - 10);
    }
    
    return custodian;
  };

  const formatOrg = (mspId: string) => {
    const orgNames: Record<string, string> = {
      'LawEnforcementMSP': 'Law Enforcement',
      'ForensicLabMSP': 'Forensic Lab',
      'JudiciaryMSP': 'Judiciary',
    };
    return orgNames[mspId] || mspId;
  };

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      REGISTERED: 'bg-blue-500',
      IN_CUSTODY: 'bg-green-500',
      IN_ANALYSIS: 'bg-yellow-500',
      ANALYZED: 'bg-purple-500',
      UNDER_REVIEW: 'bg-orange-500',
      ADMITTED: 'bg-emerald-500',
      REJECTED: 'bg-red-500',
      ARCHIVED: 'bg-gray-500',
    };
    return colors[status] || 'bg-gray-500';
  };

  const getEventIcon = (eventType: string) => {
    const icons: Record<string, React.ReactNode> = {
      REGISTRATION: <DocumentTextIcon className="h-5 w-5" />,
      TRANSFER: <ArrowsRightLeftIcon className="h-5 w-5" />,
      ANALYSIS_END: <BeakerIcon className="h-5 w-5" />,
      JUDICIAL_SUBMIT: <ScaleIcon className="h-5 w-5" />,
      JUDICIAL_DECISION: <ScaleIcon className="h-5 w-5" />,
      TAG_ADDED: <TagIcon className="h-5 w-5" />,
      VERIFICATION: <ShieldCheckIcon className="h-5 w-5" />,
    };
    return icons[eventType] || <ClockIcon className="h-5 w-5" />;
  };

  const handleTransfer = async (toEntityId: string, toOrgMSP: string, reason: string) => {
    if (!id) return;
    
    try {
      await evidenceAPI.transfer(id, { toEntityId, toOrgMSP, reason });
      toast.success('Custody transferred successfully');
      setShowTransferModal(false);
      // Refresh data
      const [evidenceRes, historyRes] = await Promise.all([
        evidenceAPI.get(id),
        evidenceAPI.getHistory(id),
      ]);
      if (evidenceRes.data.success) setEvidence(evidenceRes.data.data);
      if (historyRes.data.success) setHistory(historyRes.data.data || []);
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Transfer failed');
    }
  };

  const handleRecordAnalysis = async (data: { toolUsed: string; findings: string; artifacts?: string[]; methodology?: string }) => {
    if (!id) return;
    
    try {
      await evidenceAPI.recordAnalysis(id, data);
      toast.success('Analysis recorded successfully');
      setShowAnalysisModal(false);
      // Refresh both evidence and history
      const [evidenceRes, historyRes] = await Promise.all([
        evidenceAPI.get(id),
        evidenceAPI.getHistory(id),
      ]);
      if (evidenceRes.data.success) setEvidence(evidenceRes.data.data);
      if (historyRes.data.success) setHistory(historyRes.data.data || []);
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Failed to record analysis. Make sure evidence is transferred to Forensic Lab first.');
    }
  };

  const handleSubmitForReview = async (caseNotes: string) => {
    if (!id) return;
    
    try {
      await evidenceAPI.submitForReview(id, { caseNotes });
      toast.success('Submitted for judicial review');
      setShowReviewModal(false);
      // Refresh
      const evidenceRes = await evidenceAPI.get(id);
      if (evidenceRes.data.success) setEvidence(evidenceRes.data.data);
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Failed to submit for review');
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  if (!evidence) {
    return (
      <div className="text-center py-12">
        <h2 className="text-xl font-semibold text-white">Evidence not found</h2>
        <Link to="/evidence" className="text-blue-400 hover:text-blue-300 mt-2 inline-block">
          Back to Evidence List
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div className="flex items-center space-x-4">
          <Link
            to="/evidence"
            className="p-2 text-slate-400 hover:text-white hover:bg-slate-700 rounded-lg transition-colors"
          >
            <ArrowLeftIcon className="h-5 w-5" />
          </Link>
          <div>
            <h1 className="text-2xl font-bold text-white">{evidence.metadata.name}</h1>
            <p className="text-slate-400 font-mono text-sm">{evidence.id}</p>
          </div>
        </div>
        <div className="flex items-center space-x-3">
          <span className={`px-3 py-1.5 text-sm font-medium text-white rounded-lg ${getStatusColor(evidence.status)}`}>
            {evidence.status.replace('_', ' ')}
          </span>
          <Link
            to={`/audit/${evidence.id}`}
            className="px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white rounded-lg transition-colors"
          >
            View Audit Report
          </Link>
        </div>
      </div>

      {/* Tabs */}
      <div className="border-b border-slate-700">
        <nav className="flex space-x-8">
          {['details', 'history', 'actions'].map((tab) => (
            <button
              key={tab}
              onClick={() => setActiveTab(tab)}
              className={`py-3 px-1 border-b-2 font-medium text-sm transition-colors ${
                activeTab === tab
                  ? 'border-blue-500 text-blue-400'
                  : 'border-transparent text-slate-400 hover:text-white'
              }`}
            >
              {tab.charAt(0).toUpperCase() + tab.slice(1)}
            </button>
          ))}
        </nav>
      </div>

      {/* Tab Content */}
      {activeTab === 'details' && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Evidence Info */}
          <div className="bg-slate-800 rounded-xl border border-slate-700 p-6">
            <h3 className="text-lg font-semibold text-white mb-4">Evidence Information</h3>
            <dl className="space-y-3">
              <div className="flex justify-between">
                <dt className="text-slate-400">Case ID</dt>
                <dd className="text-white font-mono">{evidence.caseId}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-slate-400">Type</dt>
                <dd className="text-white">{evidence.metadata.type}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-slate-400">Size</dt>
                <dd className="text-white">{formatSize(evidence.metadata.size)}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-slate-400">MIME Type</dt>
                <dd className="text-white">{evidence.metadata.mimeType || 'N/A'}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-slate-400">Source Device</dt>
                <dd className="text-white">{evidence.metadata.sourceDevice || 'N/A'}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-slate-400">Registered By</dt>
                <dd className="text-white truncate max-w-[200px]">{evidence.registeredBy}</dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-slate-400">Created</dt>
                <dd className="text-white">{formatDate(evidence.createdAt)}</dd>
              </div>
            </dl>
          </div>

          {/* Custody Info */}
          <div className="bg-slate-800 rounded-xl border border-slate-700 p-6">
            <h3 className="text-lg font-semibold text-white mb-4">Custody Information</h3>
            <dl className="space-y-3">
              <div className="flex justify-between">
                <dt className="text-slate-400">Current Custodian</dt>
                <dd className="text-white" title={evidence.currentCustodian}>
                  {formatCustodian(evidence.currentCustodian, evidence.currentOrg)}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-slate-400">Organization</dt>
                <dd className="text-white">{formatOrg(evidence.currentOrg)}</dd>
              </div>
              <div className="flex justify-between items-center">
                <dt className="text-slate-400">Integrity</dt>
                <dd className="flex items-center">
                  {evidence.integrityVerified ? (
                    <span className="flex items-center text-green-400">
                      <CheckCircleIcon className="h-5 w-5 mr-1" />
                      Verified
                    </span>
                  ) : (
                    <span className="flex items-center text-yellow-400">
                      <XCircleIcon className="h-5 w-5 mr-1" />
                      Unverified
                    </span>
                  )}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-slate-400">Last Updated</dt>
                <dd className="text-white">{formatDate(evidence.updatedAt)}</dd>
              </div>
            </dl>
          </div>

          {/* Hashes */}
          <div className="bg-slate-800 rounded-xl border border-slate-700 p-6 lg:col-span-2">
            <h3 className="text-lg font-semibold text-white mb-4">Cryptographic Hashes</h3>
            <div className="space-y-4">
              <div>
                <label className="text-sm text-slate-400">Evidence Hash (SHA-256)</label>
                <p className="text-white font-mono text-sm bg-slate-900 p-3 rounded-lg break-all mt-1">
                  {evidence.evidenceHash}
                </p>
              </div>
              <div>
                <label className="text-sm text-slate-400">IPFS CID</label>
                <p className="text-white font-mono text-sm bg-slate-900 p-3 rounded-lg break-all mt-1">
                  {evidence.ipfsHash}
                </p>
              </div>
              <div>
                <label className="text-sm text-slate-400">Encryption Key ID</label>
                <p className="text-white font-mono text-sm bg-slate-900 p-3 rounded-lg break-all mt-1">
                  {evidence.encryptionKeyId}
                </p>
              </div>
              {registrationTxId && (
                <div>
                  <label className="text-sm text-slate-400">Transaction ID (TXID)</label>
                  <p className="text-white font-mono text-sm bg-slate-900 p-3 rounded-lg break-all mt-1">
                    {registrationTxId}
                  </p>
                  <p className="text-xs text-slate-500 mt-1">Registration transaction on blockchain</p>
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {activeTab === 'history' && (
        <div className="bg-slate-800 rounded-xl border border-slate-700 p-6">
          <h3 className="text-lg font-semibold text-white mb-6">Chain of Custody</h3>
          
          {history.length > 0 ? (
            <div className="relative">
              <div className="absolute left-4 top-0 bottom-0 w-0.5 bg-slate-700" />
              
              <div className="space-y-6">
                {history.map((event, index) => (
                  <div key={event.eventId} className="relative pl-10">
                    <div className={`absolute left-0 p-2 rounded-full ${
                      index === 0 ? 'bg-blue-500' : 'bg-slate-700'
                    }`}>
                      {getEventIcon(event.eventType)}
                    </div>
                    
                    <div className="bg-slate-900/50 rounded-lg p-4">
                      <div className="flex items-start justify-between mb-2">
                        <div>
                          <span className="text-white font-medium">
                            {event.eventType.replace('_', ' ')}
                          </span>
                          {event.reason && (
                            <p className="text-slate-400 text-sm mt-1">{event.reason}</p>
                          )}
                        </div>
                        <span className="text-slate-500 text-sm">
                          {formatDate(event.timestamp)}
                        </span>
                      </div>
                      
                      <div className="flex items-center space-x-4 text-sm">
                        {event.fromEntity && (
                          <div className="text-slate-400">
                            From: <span className="text-slate-300">{event.fromEntity}</span>
                          </div>
                        )}
                        {event.toEntity && (
                          <div className="text-slate-400">
                            To: <span className="text-slate-300">{event.toEntity}</span>
                          </div>
                        )}
                      </div>
                      
                      <div className="mt-2 text-xs text-slate-500 font-mono">
                        Tx: {event.txId}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <p className="text-slate-400 text-center py-8">No history available</p>
          )}
        </div>
      )}

      {activeTab === 'actions' && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <button
            onClick={() => setShowTransferModal(true)}
            className="bg-slate-800 hover:bg-slate-700 rounded-xl p-6 border border-slate-700 text-left transition-colors"
          >
            <ArrowsRightLeftIcon className="h-8 w-8 text-blue-500 mb-3" />
            <h3 className="text-white font-medium">Transfer Custody</h3>
            <p className="text-sm text-slate-400 mt-1">
              Transfer evidence to another entity or organization
            </p>
          </button>

          <button
            onClick={() => setShowAnalysisModal(true)}
            className="bg-slate-800 hover:bg-slate-700 rounded-xl p-6 border border-slate-700 text-left transition-colors"
          >
            <BeakerIcon className="h-8 w-8 text-purple-500 mb-3" />
            <h3 className="text-white font-medium">Record Analysis</h3>
            <p className="text-sm text-slate-400 mt-1">
              Document forensic analysis findings
            </p>
          </button>

          <button
            onClick={() => setShowReviewModal(true)}
            className="bg-slate-800 hover:bg-slate-700 rounded-xl p-6 border border-slate-700 text-left transition-colors"
          >
            <ScaleIcon className="h-8 w-8 text-amber-500 mb-3" />
            <h3 className="text-white font-medium">Submit for Review</h3>
            <p className="text-sm text-slate-400 mt-1">
              Submit evidence for judicial review
            </p>
          </button>
        </div>
      )}

      {/* Transfer Modal */}
      {showTransferModal && (
        <TransferModal
          onClose={() => setShowTransferModal(false)}
          onSubmit={handleTransfer}
        />
      )}

      {/* Analysis Modal */}
      {showAnalysisModal && (
        <AnalysisModal
          onClose={() => setShowAnalysisModal(false)}
          onSubmit={handleRecordAnalysis}
          currentOrg={evidence?.currentOrg}
        />
      )}

      {/* Review Modal */}
      {showReviewModal && (
        <ReviewModal
          onClose={() => setShowReviewModal(false)}
          onSubmit={handleSubmitForReview}
          currentStatus={evidence?.status}
        />
      )}
    </div>
  );
};

// User mapping for friendly names
const USERS_BY_ORG: Record<string, Array<{ id: string; name: string; role: string }>> = {
  LawEnforcementMSP: [
    { id: 'collector-le-001', name: 'Officer Ahmed (Collector)', role: 'COLLECTOR' },
    { id: 'supervisor-le-001', name: 'Sergeant Mohamed (Supervisor)', role: 'SUPERVISOR' },
  ],
  ForensicLabMSP: [
    { id: 'analyst-fl-001', name: 'Dr. Fatima (Analyst)', role: 'ANALYST' },
    { id: 'supervisor-fl-001', name: 'Dr. Khaled (Lab Supervisor)', role: 'SUPERVISOR' },
  ],
  JudiciaryMSP: [
    { id: 'counsel-jd-001', name: 'Attorney Ali (Legal Counsel)', role: 'LEGAL_COUNSEL' },
    { id: 'judge-jd-001', name: 'Judge Sara (Judge)', role: 'JUDGE' },
    { id: 'auditor-jd-001', name: 'Auditor Omar (Auditor)', role: 'AUDITOR' },
  ],
};

// Transfer Modal Component
const TransferModal: React.FC<{
  onClose: () => void;
  onSubmit: (toEntityId: string, toOrgMSP: string, reason: string) => void;
}> = ({ onClose, onSubmit }) => {
  const [toOrgMSP, setToOrgMSP] = useState('ForensicLabMSP');
  const [toEntityId, setToEntityId] = useState(USERS_BY_ORG['ForensicLabMSP'][0].id);
  const [reason, setReason] = useState('');

  const handleOrgChange = (org: string) => {
    setToOrgMSP(org);
    // Auto-select first user in org
    if (USERS_BY_ORG[org] && USERS_BY_ORG[org].length > 0) {
      setToEntityId(USERS_BY_ORG[org][0].id);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(toEntityId, toOrgMSP, reason);
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-slate-800 rounded-xl p-6 w-full max-w-md">
        <h3 className="text-lg font-semibold text-white mb-4">Transfer Custody</h3>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm text-slate-400 mb-1">To Organization</label>
            <select
              value={toOrgMSP}
              onChange={(e) => handleOrgChange(e.target.value)}
              className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white"
            >
              <option value="LawEnforcementMSP">Law Enforcement</option>
              <option value="ForensicLabMSP">Forensic Lab</option>
              <option value="JudiciaryMSP">Judiciary</option>
            </select>
          </div>
          <div>
            <label className="block text-sm text-slate-400 mb-1">To User</label>
            <select
              value={toEntityId}
              onChange={(e) => setToEntityId(e.target.value)}
              className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white"
            >
              {USERS_BY_ORG[toOrgMSP]?.map((user) => (
                <option key={user.id} value={user.id}>
                  {user.name}
                </option>
              ))}
            </select>
            <p className="text-xs text-slate-500 mt-1">User ID: {toEntityId}</p>
          </div>
          <div>
            <label className="block text-sm text-slate-400 mb-1">Reason</label>
            <textarea
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="e.g., Transfer for forensic analysis"
              className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white"
              rows={3}
              required
            />
          </div>
          <div className="flex space-x-3">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white rounded-lg"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex-1 px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg"
            >
              Transfer
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

// Analysis Modal Component
const AnalysisModal: React.FC<{
  onClose: () => void;
  onSubmit: (data: { toolUsed: string; findings: string; artifacts?: string[]; methodology?: string }) => void;
  currentOrg?: string;
}> = ({ onClose, onSubmit, currentOrg }) => {
  const [toolUsed, setToolUsed] = useState('');
  const [findings, setFindings] = useState('');
  const [artifactsText, setArtifactsText] = useState('');
  const [methodology, setMethodology] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const artifacts = artifactsText ? artifactsText.split('\n').filter(a => a.trim()) : [];
    onSubmit({ toolUsed, findings, artifacts, methodology });
  };

  const isForensicLab = currentOrg === 'ForensicLabMSP';

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-slate-800 rounded-xl p-6 w-full max-w-lg max-h-[90vh] overflow-y-auto">
        <h3 className="text-lg font-semibold text-white mb-4">Record Analysis</h3>
        
        {!isForensicLab && (
          <div className="mb-4 p-3 bg-amber-500/20 border border-amber-500/50 rounded-lg">
            <p className="text-amber-400 text-sm">
              ⚠️ Evidence must be transferred to Forensic Lab organization before analysis can be recorded.
              Current organization: {currentOrg || 'Unknown'}
            </p>
          </div>
        )}
        
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm text-slate-400 mb-1">Tool Used</label>
            <select
              value={toolUsed}
              onChange={(e) => setToolUsed(e.target.value)}
              className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white"
              required
            >
              <option value="">Select a tool...</option>
              <option value="Autopsy">Autopsy</option>
              <option value="EnCase">EnCase</option>
              <option value="FTK (Forensic Toolkit)">FTK (Forensic Toolkit)</option>
              <option value="Volatility">Volatility</option>
              <option value="X-Ways Forensics">X-Ways Forensics</option>
              <option value="Cellebrite">Cellebrite</option>
              <option value="Other">Other</option>
            </select>
          </div>
          <div>
            <label className="block text-sm text-slate-400 mb-1">Findings</label>
            <textarea
              value={findings}
              onChange={(e) => setFindings(e.target.value)}
              placeholder="Describe the analysis findings..."
              className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white"
              rows={4}
              required
            />
          </div>
          <div>
            <label className="block text-sm text-slate-400 mb-1">Artifacts Found (one per line)</label>
            <textarea
              value={artifactsText}
              onChange={(e) => setArtifactsText(e.target.value)}
              placeholder="suspicious_file.exe&#10;browser_history.db&#10;keylogger.dll"
              className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white font-mono text-sm"
              rows={3}
            />
          </div>
          <div>
            <label className="block text-sm text-slate-400 mb-1">Methodology</label>
            <input
              type="text"
              value={methodology}
              onChange={(e) => setMethodology(e.target.value)}
              placeholder="e.g., NIST SP 800-86 Guidelines"
              className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white"
            />
          </div>
          <div className="flex space-x-3">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white rounded-lg"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex-1 px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg"
            >
              Record
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

// Review Modal Component
const ReviewModal: React.FC<{
  onClose: () => void;
  onSubmit: (caseNotes: string) => void;
  currentStatus?: string;
}> = ({ onClose, onSubmit, currentStatus }) => {
  const [caseNotes, setCaseNotes] = useState('');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(caseNotes);
  };

  // Check if status allows submission for review
  const canSubmit = ['IN_CUSTODY', 'ANALYZED'].includes(currentStatus || '');

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-slate-800 rounded-xl p-6 w-full max-w-md">
        <h3 className="text-lg font-semibold text-white mb-4">Submit for Judicial Review</h3>
        
        {!canSubmit && (
          <div className="mb-4 p-3 bg-amber-500/20 border border-amber-500/50 rounded-lg">
            <p className="text-amber-400 text-sm">
              ⚠️ Evidence must be in "IN_CUSTODY" or "ANALYZED" status to submit for review.
              Current status: <strong>{currentStatus || 'Unknown'}</strong>
            </p>
            <p className="text-amber-400/70 text-xs mt-1">
              Workflow: REGISTERED → Transfer → IN_CUSTODY → Analysis → ANALYZED → Submit for Review
            </p>
          </div>
        )}
        
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-sm text-slate-400 mb-1">Case Notes</label>
            <textarea
              value={caseNotes}
              onChange={(e) => setCaseNotes(e.target.value)}
              placeholder="Provide summary of evidence and analysis findings for judicial review..."
              className="w-full px-3 py-2 bg-slate-700 border border-slate-600 rounded-lg text-white"
              rows={5}
              required
            />
          </div>
          <div className="flex space-x-3">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white rounded-lg"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="flex-1 px-4 py-2 bg-amber-600 hover:bg-amber-700 text-white rounded-lg"
            >
              Submit
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default EvidenceDetail;

