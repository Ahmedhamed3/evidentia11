import React, { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { auditAPI, AuditReportData } from '../services/api';
import toast from 'react-hot-toast';
import {
  ArrowLeftIcon,
  DocumentArrowDownIcon,
  ShieldCheckIcon,
  ClockIcon,
  UserIcon,
  BuildingOfficeIcon,
  HashtagIcon,
  CheckCircleIcon,
  XCircleIcon,
} from '@heroicons/react/24/outline';

const AuditReport: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const [report, setReport] = useState<AuditReportData | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchReport = async () => {
      if (!id) return;
      
      try {
        const response = await auditAPI.getReport(id);
        if (response.data.success) {
          setReport(response.data.data);
        }
      } catch (error) {
        console.error('Failed to fetch audit report:', error);
        toast.error('Failed to load audit report');
      } finally {
        setLoading(false);
      }
    };

    fetchReport();
  }, [id]);

  const formatDate = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleString();
  };

  const formatSize = (bytes: number) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  };

  const handleExport = async (format: 'json' | 'text') => {
    if (!id) return;
    
    try {
      const response = await auditAPI.exportReport(id, format);
      
      // Create download link
      const blob = format === 'json' 
        ? new Blob([JSON.stringify(response.data, null, 2)], { type: 'application/json' })
        : new Blob([response.data], { type: 'text/plain' });
      
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `audit-report-${id}.${format === 'json' ? 'json' : 'txt'}`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
      
      toast.success('Report exported successfully');
    } catch (error) {
      toast.error('Failed to export report');
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  if (!report) {
    return (
      <div className="text-center py-12">
        <h2 className="text-xl font-semibold text-white">Report not found</h2>
        <Link to="/evidence" className="text-blue-400 hover:text-blue-300 mt-2 inline-block">
          Back to Evidence List
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-6 max-w-5xl mx-auto">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div className="flex items-center space-x-4">
          <Link
            to={`/evidence/${id}`}
            className="p-2 text-slate-400 hover:text-white hover:bg-slate-700 rounded-lg transition-colors"
          >
            <ArrowLeftIcon className="h-5 w-5" />
          </Link>
          <div>
            <h1 className="text-2xl font-bold text-white">Audit Report</h1>
            <p className="text-slate-400 font-mono text-sm">{report.reportId}</p>
          </div>
        </div>
        <div className="flex items-center space-x-3">
          <button
            onClick={() => handleExport('json')}
            className="flex items-center px-4 py-2 bg-slate-700 hover:bg-slate-600 text-white rounded-lg transition-colors"
          >
            <DocumentArrowDownIcon className="h-5 w-5 mr-2" />
            Export JSON
          </button>
          <button
            onClick={() => handleExport('text')}
            className="flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
          >
            <DocumentArrowDownIcon className="h-5 w-5 mr-2" />
            Export Report
          </button>
        </div>
      </div>

      {/* Report Header */}
      <div className="bg-gradient-to-r from-blue-600 to-purple-600 rounded-xl p-6 text-white">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-xl font-bold">Digital Evidence Chain-of-Custody Report</h2>
          {report.verified ? (
            <span className="flex items-center px-3 py-1 bg-green-500/20 rounded-full text-green-200">
              <CheckCircleIcon className="h-5 w-5 mr-1" />
              Verified
            </span>
          ) : (
            <span className="flex items-center px-3 py-1 bg-yellow-500/20 rounded-full text-yellow-200">
              <XCircleIcon className="h-5 w-5 mr-1" />
              Unverified
            </span>
          )}
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
          <div>
            <p className="text-blue-200">Generated</p>
            <p className="font-medium">{formatDate(report.generatedAt)}</p>
          </div>
          <div>
            <p className="text-blue-200">Generated By</p>
            <p className="font-medium truncate">{report.generatedBy}</p>
          </div>
          <div className="md:col-span-2">
            <p className="text-blue-200">Integrity Hash</p>
            <p className="font-mono text-xs truncate">{report.integrityHash}</p>
          </div>
        </div>
      </div>

      {/* Evidence Summary */}
      <div className="bg-slate-800 rounded-xl border border-slate-700 p-6">
        <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
          <ShieldCheckIcon className="h-5 w-5 mr-2 text-blue-500" />
          Evidence Information
        </h3>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="space-y-4">
            <div className="flex items-start space-x-3">
              <HashtagIcon className="h-5 w-5 text-slate-500 mt-0.5" />
              <div>
                <p className="text-sm text-slate-400">Evidence ID</p>
                <p className="text-white font-mono">{report.evidence.id}</p>
              </div>
            </div>
            <div className="flex items-start space-x-3">
              <HashtagIcon className="h-5 w-5 text-slate-500 mt-0.5" />
              <div>
                <p className="text-sm text-slate-400">Case ID</p>
                <p className="text-white font-mono">{report.evidence.caseId}</p>
              </div>
            </div>
            <div className="flex items-start space-x-3">
              <BuildingOfficeIcon className="h-5 w-5 text-slate-500 mt-0.5" />
              <div>
                <p className="text-sm text-slate-400">Current Organization</p>
                <p className="text-white">{report.evidence.currentOrg}</p>
              </div>
            </div>
          </div>
          
          <div className="space-y-4">
            <div>
              <p className="text-sm text-slate-400">Name</p>
              <p className="text-white">{report.evidence.metadata.name}</p>
            </div>
            <div>
              <p className="text-sm text-slate-400">Type / Size</p>
              <p className="text-white">
                {report.evidence.metadata.type} • {formatSize(report.evidence.metadata.size)}
              </p>
            </div>
            <div>
              <p className="text-sm text-slate-400">Status</p>
              <p className="text-white">{report.evidence.status.replace('_', ' ')}</p>
            </div>
          </div>
        </div>

        {/* Hashes */}
        <div className="mt-6 pt-6 border-t border-slate-700">
          <h4 className="text-sm font-medium text-slate-400 mb-3">Cryptographic Hashes</h4>
          <div className="space-y-2">
            <div className="bg-slate-900/50 p-3 rounded-lg">
              <p className="text-xs text-slate-500 mb-1">SHA-256 Hash</p>
              <p className="text-white font-mono text-sm break-all">{report.evidence.evidenceHash}</p>
            </div>
            <div className="bg-slate-900/50 p-3 rounded-lg">
              <p className="text-xs text-slate-500 mb-1">IPFS CID</p>
              <p className="text-white font-mono text-sm break-all">{report.evidence.ipfsHash}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Chain of Custody */}
      <div className="bg-slate-800 rounded-xl border border-slate-700 p-6">
        <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
          <ClockIcon className="h-5 w-5 mr-2 text-green-500" />
          Chain of Custody ({report.custodyChain?.length || 0} Events)
        </h3>
        
        {report.custodyChain && report.custodyChain.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="text-left text-xs font-medium text-slate-400 uppercase border-b border-slate-700">
                  <th className="pb-3 pr-4">#</th>
                  <th className="pb-3 pr-4">Event Type</th>
                  <th className="pb-3 pr-4">From</th>
                  <th className="pb-3 pr-4">To</th>
                  <th className="pb-3 pr-4">Timestamp</th>
                  <th className="pb-3">Transaction</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-700/50">
                {report.custodyChain.map((event, index) => (
                  <tr key={event.eventId} className="text-sm">
                    <td className="py-3 pr-4 text-slate-500">{index + 1}</td>
                    <td className="py-3 pr-4">
                      <span className="px-2 py-1 bg-slate-700 text-slate-300 rounded text-xs">
                        {event.eventType}
                      </span>
                    </td>
                    <td className="py-3 pr-4">
                      <div>
                        <p className="text-white truncate max-w-[150px]">
                          {event.fromEntity || '-'}
                        </p>
                        <p className="text-xs text-slate-500">{event.fromOrg || '-'}</p>
                      </div>
                    </td>
                    <td className="py-3 pr-4">
                      <div>
                        <p className="text-white truncate max-w-[150px]">
                          {event.toEntity || '-'}
                        </p>
                        <p className="text-xs text-slate-500">{event.toOrg || '-'}</p>
                      </div>
                    </td>
                    <td className="py-3 pr-4 text-slate-300">
                      {formatDate(event.timestamp)}
                    </td>
                    <td className="py-3">
                      <code className="text-xs text-slate-500 truncate block max-w-[200px]">
                        {event.txId}
                      </code>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <p className="text-slate-400 text-center py-8">No custody events recorded</p>
        )}
      </div>

      {/* Analysis Records */}
      <div className="bg-slate-800 rounded-xl border border-slate-700 p-6">
        <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
          <UserIcon className="h-5 w-5 mr-2 text-purple-500" />
          Analysis Records ({report.analysisRecords?.length || 0})
        </h3>
        
        {report.analysisRecords && report.analysisRecords.length > 0 ? (
          <div className="space-y-4">
            {report.analysisRecords.map((analysis, index) => (
              <div key={analysis.analysisId} className="bg-slate-900/50 rounded-lg p-4">
                <div className="flex items-start justify-between mb-2">
                  <div>
                    <span className="text-white font-medium">
                      Analysis #{index + 1}
                    </span>
                    <span className="text-slate-500 text-sm ml-2">
                      {analysis.analysisId}
                    </span>
                  </div>
                  {analysis.verified ? (
                    <span className="text-green-400 text-sm flex items-center">
                      <CheckCircleIcon className="h-4 w-4 mr-1" />
                      Verified
                    </span>
                  ) : (
                    <span className="text-yellow-400 text-sm">Pending Verification</span>
                  )}
                </div>
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <p className="text-slate-400">Tool Used</p>
                    <p className="text-white">{analysis.toolUsed} v{analysis.toolVersion}</p>
                  </div>
                  <div>
                    <p className="text-slate-400">Analyst</p>
                    <p className="text-white truncate">{analysis.analystId}</p>
                  </div>
                </div>
                {analysis.findings && (
                  <div className="mt-3">
                    <p className="text-slate-400 text-sm">Findings</p>
                    <p className="text-slate-300 text-sm mt-1">{analysis.findings}</p>
                  </div>
                )}
              </div>
            ))}
          </div>
        ) : (
          <p className="text-slate-400 text-center py-8">No analysis records</p>
        )}
      </div>

      {/* Judicial Reviews */}
      <div className="bg-slate-800 rounded-xl border border-slate-700 p-6">
        <h3 className="text-lg font-semibold text-white mb-4 flex items-center">
          <BuildingOfficeIcon className="h-5 w-5 mr-2 text-amber-500" />
          Judicial Reviews ({report.judicialReviews?.length || 0})
        </h3>
        
        {report.judicialReviews && report.judicialReviews.length > 0 ? (
          <div className="space-y-4">
            {report.judicialReviews.map((review) => (
              <div key={review.reviewId} className="bg-slate-900/50 rounded-lg p-4">
                <div className="flex items-start justify-between mb-2">
                  <div>
                    <span className="text-white font-medium">
                      Review: {review.reviewId}
                    </span>
                  </div>
                  <span className={`px-2 py-1 rounded text-sm ${
                    review.decision === 'ADMITTED' 
                      ? 'bg-green-500/20 text-green-400'
                      : review.decision === 'REJECTED'
                      ? 'bg-red-500/20 text-red-400'
                      : 'bg-yellow-500/20 text-yellow-400'
                  }`}>
                    {review.decision}
                  </span>
                </div>
                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <p className="text-slate-400">Submitted</p>
                    <p className="text-white">{formatDate(review.submittedAt)}</p>
                  </div>
                  {review.decidedAt && (
                    <div>
                      <p className="text-slate-400">Decided</p>
                      <p className="text-white">{formatDate(review.decidedAt)}</p>
                    </div>
                  )}
                </div>
                {review.decisionReason && (
                  <div className="mt-3">
                    <p className="text-slate-400 text-sm">Decision Reason</p>
                    <p className="text-slate-300 text-sm mt-1">{review.decisionReason}</p>
                  </div>
                )}
              </div>
            ))}
          </div>
        ) : (
          <p className="text-slate-400 text-center py-8">No judicial reviews</p>
        )}
      </div>
    </div>
  );
};

export default AuditReport;

