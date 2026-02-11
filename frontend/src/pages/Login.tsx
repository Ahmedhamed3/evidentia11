import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { authAPI } from '../services/api';
import { ShieldCheckIcon, LockClosedIcon, UserIcon } from '@heroicons/react/24/outline';

interface DemoUser {
  username: string;
  organization: string;
  role: string;
  commonName: string;
}

const Login: React.FC = () => {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [demoUsers, setDemoUsers] = useState<DemoUser[]>([]);
  const { login, isAuthenticated } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    if (isAuthenticated) {
      navigate('/');
    }
  }, [isAuthenticated, navigate]);

  useEffect(() => {
    // Fetch demo users
    const fetchUsers = async () => {
      try {
        const response = await authAPI.getUsers();
        if (response.data.success) {
          setDemoUsers(response.data.data);
        }
      } catch (error) {
        console.error('Failed to fetch demo users:', error);
      }
    };
    fetchUsers();
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    const success = await login(username, password);
    
    setLoading(false);
    if (success) {
      navigate('/');
    }
  };

  const selectDemoUser = (user: DemoUser) => {
    setUsername(user.username);
    setPassword(user.username === 'admin' ? 'admin123' : 'password123');
  };

  const getOrgColor = (org: string) => {
    const colors: Record<string, string> = {
      LawEnforcement: 'border-blue-500 bg-blue-500/10',
      ForensicLab: 'border-purple-500 bg-purple-500/10',
      Judiciary: 'border-amber-500 bg-amber-500/10',
    };
    return colors[org] || 'border-gray-500 bg-gray-500/10';
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center p-4">
      <div className="w-full max-w-5xl grid md:grid-cols-2 gap-8">
        {/* Login Form */}
        <div className="bg-slate-800/50 backdrop-blur-sm rounded-2xl p-8 border border-slate-700">
          <div className="flex items-center justify-center mb-8">
            <ShieldCheckIcon className="h-12 w-12 text-blue-500" />
            <h1 className="text-3xl font-bold text-white ml-3">Evidentia</h1>
          </div>
          
          <p className="text-center text-slate-400 mb-8">
            Blockchain-Based Digital Evidence<br />Chain-of-Custody System
          </p>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">
                Username
              </label>
              <div className="relative">
                <UserIcon className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-500" />
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  className="w-full pl-10 pr-4 py-3 bg-slate-700/50 border border-slate-600 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="Enter username"
                  required
                />
              </div>
            </div>

            <div>
              <label className="block text-sm font-medium text-slate-300 mb-2">
                Password
              </label>
              <div className="relative">
                <LockClosedIcon className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-slate-500" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full pl-10 pr-4 py-3 bg-slate-700/50 border border-slate-600 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  placeholder="Enter password"
                  required
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 px-4 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-600/50 text-white font-medium rounded-lg transition-colors flex items-center justify-center"
            >
              {loading ? (
                <div className="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent" />
              ) : (
                'Sign In'
              )}
            </button>
          </form>
        </div>

        {/* Demo Users */}
        <div className="bg-slate-800/30 backdrop-blur-sm rounded-2xl p-6 border border-slate-700/50">
          <h2 className="text-lg font-semibold text-white mb-4">Demo Users</h2>
          <p className="text-sm text-slate-400 mb-4">
            Click a user to auto-fill credentials
          </p>
          
          <div className="space-y-2 max-h-[500px] overflow-y-auto pr-2">
            {demoUsers.map((user) => (
              <button
                key={user.username}
                onClick={() => selectDemoUser(user)}
                className={`w-full text-left p-3 rounded-lg border-l-4 transition-all hover:scale-[1.02] ${getOrgColor(user.organization)}`}
              >
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-white font-medium">{user.commonName}</p>
                    <p className="text-sm text-slate-400">{user.username}</p>
                  </div>
                  <div className="text-right">
                    <span className="inline-block px-2 py-1 text-xs font-medium bg-slate-700 text-slate-300 rounded">
                      {user.role}
                    </span>
                    <p className="text-xs text-slate-500 mt-1">{user.organization}</p>
                  </div>
                </div>
              </button>
            ))}
          </div>

          <div className="mt-4 p-3 bg-slate-700/30 rounded-lg">
            <p className="text-xs text-slate-400">
              <strong className="text-slate-300">Default passwords:</strong><br />
              All users: <code className="text-blue-400">password123</code><br />
              Admin: <code className="text-blue-400">admin123</code>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Login;

