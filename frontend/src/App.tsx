import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { AuthProvider, useAuth } from './context/AuthContext';
import Layout from './components/Layout';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import EvidenceList from './pages/EvidenceList';
import EvidenceDetail from './pages/EvidenceDetail';
import RegisterEvidence from './pages/RegisterEvidence';
import AuditReport from './pages/AuditReport';

// Protected route wrapper
const ProtectedRoute: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { isAuthenticated, loading } = useAuth();
  
  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-slate-900">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500"></div>
      </div>
    );
  }
  
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }
  
  return <>{children}</>;
};

function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/" element={
        <ProtectedRoute>
          <Layout>
            <Dashboard />
          </Layout>
        </ProtectedRoute>
      } />
      <Route path="/evidence" element={
        <ProtectedRoute>
          <Layout>
            <EvidenceList />
          </Layout>
        </ProtectedRoute>
      } />
      <Route path="/evidence/register" element={
        <ProtectedRoute>
          <Layout>
            <RegisterEvidence />
          </Layout>
        </ProtectedRoute>
      } />
      <Route path="/evidence/:id" element={
        <ProtectedRoute>
          <Layout>
            <EvidenceDetail />
          </Layout>
        </ProtectedRoute>
      } />
      <Route path="/audit/:id" element={
        <ProtectedRoute>
          <Layout>
            <AuditReport />
          </Layout>
        </ProtectedRoute>
      } />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

function App() {
  return (
    <AuthProvider>
      <Router>
        <AppRoutes />
        <Toaster 
          position="top-right"
          toastOptions={{
            duration: 4000,
            style: {
              background: '#1e293b',
              color: '#f8fafc',
            },
            success: {
              iconTheme: {
                primary: '#22c55e',
                secondary: '#f8fafc',
              },
            },
            error: {
              iconTheme: {
                primary: '#ef4444',
                secondary: '#f8fafc',
              },
            },
          }}
        />
      </Router>
    </AuthProvider>
  );
}

export default App;

