import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { evidenceAPI, Evidence } from '../services/api';
import {
  DocumentMagnifyingGlassIcon,
  ClockIcon,
  ShieldCheckIcon,
  ExclamationTriangleIcon,
  ArrowTrendingUpIcon,
  PlusIcon,
} from '@heroicons/react/24/outline';

const Dashboard: React.FC = () => {
  const { user } = useAuth();
  const [evidence, setEvidence] = useState<Evidence[]>([]);
  const [loading, setLoading] = useState(true);
  const [stats, setStats] = useState({
    total: 0,
    inCustody: 0,
    inAnalysis: 0,
    underReview: 0,
    verified: 0,
  });

  useEffect(() => {
    const fetchEvidence = async () => {
      try {
        const response = await evidenceAPI.list();
        if (response.data.success) {
          const data = response.data.data || [];
          setEvidence(data);
          
          // Calculate stats
          setStats({
            total: data.length,
            inCustody: data.filter((e: Evidence) => e.status === 'IN_CUSTODY').length,
            inAnalysis: data.filter((e: Evidence) => e.status === 'IN_ANALYSIS').length,
            underReview: data.filter((e: Evidence) => e.status === 'UNDER_REVIEW').length,
            verified: data.filter((e: Evidence) => e.integrityVerified).length,
          });
        }
      } catch (error) {
        console.error('Failed to fetch evidence:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchEvidence();
  }, []);

  const recentEvidence = evidence
    .sort((a, b) => b.updatedAt - a.updatedAt)
    .slice(0, 5);

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

  const formatDate = (timestamp: number) => {
    return new Date(timestamp * 1000).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Dashboard</h1>
          <p className="text-slate-400">
            Welcome back, {user?.commonName}
          </p>
        </div>
        <Link
          to="/evidence/register"
          className="flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors"
        >
          <PlusIcon className="h-5 w-5 mr-2" />
          Register Evidence
        </Link>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
        <div className="bg-slate-800 rounded-xl p-5 border border-slate-700">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-slate-400 text-sm">Total Evidence</p>
              <p className="text-2xl font-bold text-white mt-1">{stats.total}</p>
            </div>
            <div className="p-3 bg-blue-500/20 rounded-lg">
              <DocumentMagnifyingGlassIcon className="h-6 w-6 text-blue-500" />
            </div>
          </div>
        </div>

        <div className="bg-slate-800 rounded-xl p-5 border border-slate-700">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-slate-400 text-sm">In Custody</p>
              <p className="text-2xl font-bold text-white mt-1">{stats.inCustody}</p>
            </div>
            <div className="p-3 bg-green-500/20 rounded-lg">
              <ShieldCheckIcon className="h-6 w-6 text-green-500" />
            </div>
          </div>
        </div>

        <div className="bg-slate-800 rounded-xl p-5 border border-slate-700">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-slate-400 text-sm">In Analysis</p>
              <p className="text-2xl font-bold text-white mt-1">{stats.inAnalysis}</p>
            </div>
            <div className="p-3 bg-yellow-500/20 rounded-lg">
              <ArrowTrendingUpIcon className="h-6 w-6 text-yellow-500" />
            </div>
          </div>
        </div>

        <div className="bg-slate-800 rounded-xl p-5 border border-slate-700">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-slate-400 text-sm">Under Review</p>
              <p className="text-2xl font-bold text-white mt-1">{stats.underReview}</p>
            </div>
            <div className="p-3 bg-orange-500/20 rounded-lg">
              <ClockIcon className="h-6 w-6 text-orange-500" />
            </div>
          </div>
        </div>

        <div className="bg-slate-800 rounded-xl p-5 border border-slate-700">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-slate-400 text-sm">Integrity Verified</p>
              <p className="text-2xl font-bold text-white mt-1">{stats.verified}</p>
            </div>
            <div className="p-3 bg-emerald-500/20 rounded-lg">
              <ShieldCheckIcon className="h-6 w-6 text-emerald-500" />
            </div>
          </div>
        </div>
      </div>

      {/* Recent Evidence */}
      <div className="bg-slate-800 rounded-xl border border-slate-700">
        <div className="p-5 border-b border-slate-700">
          <h2 className="text-lg font-semibold text-white">Recent Activity</h2>
        </div>
        
        {recentEvidence.length > 0 ? (
          <div className="divide-y divide-slate-700">
            {recentEvidence.map((item) => (
              <Link
                key={item.id}
                to={`/evidence/${item.id}`}
                className="flex items-center justify-between p-4 hover:bg-slate-700/50 transition-colors"
              >
                <div className="flex items-center space-x-4">
                  <div className={`w-2 h-2 rounded-full ${getStatusColor(item.status)}`} />
                  <div>
                    <p className="text-white font-medium">{item.metadata.name}</p>
                    <p className="text-sm text-slate-400">
                      Case: {item.caseId} • {item.id}
                    </p>
                  </div>
                </div>
                <div className="text-right">
                  <span className={`inline-block px-2 py-1 text-xs font-medium rounded ${getStatusColor(item.status)} text-white`}>
                    {item.status.replace('_', ' ')}
                  </span>
                  <p className="text-xs text-slate-500 mt-1">
                    {formatDate(item.updatedAt)}
                  </p>
                </div>
              </Link>
            ))}
          </div>
        ) : (
          <div className="p-8 text-center">
            <ExclamationTriangleIcon className="h-12 w-12 text-slate-600 mx-auto mb-3" />
            <p className="text-slate-400">No evidence registered yet</p>
            <Link
              to="/evidence/register"
              className="inline-flex items-center mt-3 text-blue-400 hover:text-blue-300"
            >
              <PlusIcon className="h-4 w-4 mr-1" />
              Register your first evidence
            </Link>
          </div>
        )}
      </div>

      {/* Quick Actions */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Link
          to="/evidence"
          className="bg-slate-800 hover:bg-slate-700 rounded-xl p-5 border border-slate-700 transition-colors group"
        >
          <DocumentMagnifyingGlassIcon className="h-8 w-8 text-blue-500 mb-3" />
          <h3 className="text-white font-medium group-hover:text-blue-400 transition-colors">
            Browse Evidence
          </h3>
          <p className="text-sm text-slate-400 mt-1">
            View and manage all registered evidence
          </p>
        </Link>

        <Link
          to="/evidence/register"
          className="bg-slate-800 hover:bg-slate-700 rounded-xl p-5 border border-slate-700 transition-colors group"
        >
          <PlusIcon className="h-8 w-8 text-green-500 mb-3" />
          <h3 className="text-white font-medium group-hover:text-green-400 transition-colors">
            Register Evidence
          </h3>
          <p className="text-sm text-slate-400 mt-1">
            Upload and register new digital evidence
          </p>
        </Link>

        <div className="bg-slate-800 rounded-xl p-5 border border-slate-700">
          <ShieldCheckIcon className="h-8 w-8 text-purple-500 mb-3" />
          <h3 className="text-white font-medium">Your Role</h3>
          <p className="text-sm text-slate-400 mt-1">
            {user?.role} @ {user?.organization}
          </p>
          <p className="text-xs text-slate-500 mt-2">
            MSP: {user?.mspId}
          </p>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;

