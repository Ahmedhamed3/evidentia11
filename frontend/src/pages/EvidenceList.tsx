import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { evidenceAPI, Evidence } from '../services/api';
import {
  MagnifyingGlassIcon,
  FunnelIcon,
  DocumentMagnifyingGlassIcon,
  ShieldCheckIcon,
  ExclamationTriangleIcon,
} from '@heroicons/react/24/outline';

const EvidenceList: React.FC = () => {
  const [evidence, setEvidence] = useState<Evidence[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('');

  useEffect(() => {
    const fetchEvidence = async () => {
      try {
        const params: { status?: string } = {};
        if (statusFilter) params.status = statusFilter;
        
        const response = await evidenceAPI.list(params);
        if (response.data.success) {
          setEvidence(response.data.data || []);
        }
      } catch (error) {
        console.error('Failed to fetch evidence:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchEvidence();
  }, [statusFilter]);

  const filteredEvidence = evidence.filter((item) => {
    const matchesSearch = 
      item.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.caseId.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.metadata.name.toLowerCase().includes(searchTerm.toLowerCase());
    
    return matchesSearch;
  });

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      REGISTERED: 'bg-blue-100 text-blue-800',
      IN_CUSTODY: 'bg-green-100 text-green-800',
      IN_ANALYSIS: 'bg-yellow-100 text-yellow-800',
      ANALYZED: 'bg-purple-100 text-purple-800',
      UNDER_REVIEW: 'bg-orange-100 text-orange-800',
      ADMITTED: 'bg-emerald-100 text-emerald-800',
      REJECTED: 'bg-red-100 text-red-800',
      ARCHIVED: 'bg-gray-100 text-gray-800',
    };
    return colors[status] || 'bg-gray-100 text-gray-800';
  };

  const formatDate = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  const formatSize = (bytes: number) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    return (bytes / (1024 * 1024 * 1024)).toFixed(1) + ' GB';
  };

  const statuses = [
    'REGISTERED',
    'IN_CUSTODY',
    'IN_ANALYSIS',
    'ANALYZED',
    'UNDER_REVIEW',
    'ADMITTED',
    'REJECTED',
    'ARCHIVED',
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Evidence Registry</h1>
          <p className="text-slate-400">
            {filteredEvidence.length} items found
          </p>
        </div>
        <Link
          to="/evidence/register"
          className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
        >
          Register New Evidence
        </Link>
      </div>

      {/* Filters */}
      <div className="flex flex-col sm:flex-row gap-4">
        <div className="relative flex-1">
          <MagnifyingGlassIcon className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-500" />
          <input
            type="text"
            placeholder="Search by ID, case, or name..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 bg-slate-800 border border-slate-700 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
        </div>
        <div className="relative">
          <FunnelIcon className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-500" />
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="pl-10 pr-8 py-2.5 bg-slate-800 border border-slate-700 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500 appearance-none cursor-pointer"
          >
            <option value="">All Statuses</option>
            {statuses.map((status) => (
              <option key={status} value={status}>
                {status.replace('_', ' ')}
              </option>
            ))}
          </select>
        </div>
      </div>

      {/* Evidence List */}
      {loading ? (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500"></div>
        </div>
      ) : filteredEvidence.length > 0 ? (
        <div className="bg-slate-800 rounded-xl border border-slate-700 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-slate-900/50">
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-400 uppercase">
                    Evidence
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-400 uppercase">
                    Case ID
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-400 uppercase">
                    Status
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-400 uppercase">
                    Custodian
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-400 uppercase">
                    Size
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-400 uppercase">
                    Integrity
                  </th>
                  <th className="px-4 py-3 text-left text-xs font-medium text-slate-400 uppercase">
                    Created
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-700">
                {filteredEvidence.map((item) => (
                  <tr
                    key={item.id}
                    className="hover:bg-slate-700/30 transition-colors"
                  >
                    <td className="px-4 py-4">
                      <Link
                        to={`/evidence/${item.id}`}
                        className="flex items-center space-x-3 group"
                      >
                        <DocumentMagnifyingGlassIcon className="h-8 w-8 text-slate-500 group-hover:text-blue-500 transition-colors" />
                        <div>
                          <p className="text-white font-medium group-hover:text-blue-400 transition-colors">
                            {item.metadata.name}
                          </p>
                          <p className="text-xs text-slate-500 font-mono">
                            {item.id}
                          </p>
                        </div>
                      </Link>
                    </td>
                    <td className="px-4 py-4">
                      <span className="text-slate-300 font-mono text-sm">
                        {item.caseId}
                      </span>
                    </td>
                    <td className="px-4 py-4">
                      <span className={`inline-block px-2 py-1 text-xs font-medium rounded ${getStatusColor(item.status)}`}>
                        {item.status.replace('_', ' ')}
                      </span>
                    </td>
                    <td className="px-4 py-4">
                      <div>
                        <p className="text-slate-300 text-sm truncate max-w-[150px]">
                          {item.currentCustodian}
                        </p>
                        <p className="text-xs text-slate-500">
                          {item.currentOrg}
                        </p>
                      </div>
                    </td>
                    <td className="px-4 py-4">
                      <span className="text-slate-400 text-sm">
                        {formatSize(item.metadata.size)}
                      </span>
                    </td>
                    <td className="px-4 py-4">
                      {item.integrityVerified ? (
                        <span className="flex items-center text-green-400 text-sm">
                          <ShieldCheckIcon className="h-4 w-4 mr-1" />
                          Verified
                        </span>
                      ) : (
                        <span className="flex items-center text-yellow-400 text-sm">
                          <ExclamationTriangleIcon className="h-4 w-4 mr-1" />
                          Unverified
                        </span>
                      )}
                    </td>
                    <td className="px-4 py-4">
                      <span className="text-slate-400 text-sm">
                        {formatDate(item.createdAt)}
                      </span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      ) : (
        <div className="bg-slate-800 rounded-xl border border-slate-700 p-12 text-center">
          <DocumentMagnifyingGlassIcon className="h-16 w-16 text-slate-600 mx-auto mb-4" />
          <h3 className="text-lg font-medium text-white mb-2">No evidence found</h3>
          <p className="text-slate-400 mb-4">
            {searchTerm || statusFilter
              ? 'Try adjusting your search or filter criteria'
              : 'Get started by registering your first piece of evidence'}
          </p>
          {!searchTerm && !statusFilter && (
            <Link
              to="/evidence/register"
              className="inline-flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
            >
              Register Evidence
            </Link>
          )}
        </div>
      )}
    </div>
  );
};

export default EvidenceList;

