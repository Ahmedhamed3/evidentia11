import React, { useState, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useDropzone } from 'react-dropzone';
import { evidenceAPI } from '../services/api';
import toast from 'react-hot-toast';
import {
  CloudArrowUpIcon,
  DocumentIcon,
  XMarkIcon,
} from '@heroicons/react/24/outline';

const RegisterEvidence: React.FC = () => {
  const navigate = useNavigate();
  const [loading, setLoading] = useState(false);
  const [file, setFile] = useState<File | null>(null);
  const [formData, setFormData] = useState({
    caseId: '',
    name: '',
    type: 'Digital Image',
    sourceDevice: '',
    location: '',
    notes: '',
  });

  const onDrop = useCallback((acceptedFiles: File[]) => {
    if (acceptedFiles.length > 0) {
      const selectedFile = acceptedFiles[0];
      setFile(selectedFile);
      // Auto-fill name if empty
      if (!formData.name) {
        setFormData(prev => ({ ...prev, name: selectedFile.name }));
      }
    }
  }, [formData.name]);

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    maxFiles: 1,
    maxSize: 100 * 1024 * 1024, // 100MB
  });

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const removeFile = () => {
    setFile(null);
  };

  const formatSize = (bytes: number) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!file) {
      toast.error('Please select a file');
      return;
    }
    
    if (!formData.caseId) {
      toast.error('Case ID is required');
      return;
    }
    
    setLoading(true);
    
    try {
      const submitData = new FormData();
      submitData.append('file', file);
      submitData.append('caseId', formData.caseId);
      submitData.append('name', formData.name || file.name);
      submitData.append('type', formData.type);
      submitData.append('sourceDevice', formData.sourceDevice);
      submitData.append('location', formData.location);
      submitData.append('notes', formData.notes);
      
      const response = await evidenceAPI.register(submitData);
      
      if (response.data.success) {
        toast.success('Evidence registered successfully!');
        navigate(`/evidence/${response.data.data.evidenceId}`);
      } else {
        toast.error(response.data.error || 'Registration failed');
      }
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Failed to register evidence');
    } finally {
      setLoading(false);
    }
  };

  const evidenceTypes = [
    'Digital Image',
    'Disk Image',
    'Memory Dump',
    'Network Capture',
    'Mobile Device',
    'Document',
    'Email',
    'Log File',
    'Database',
    'Other',
  ];

  return (
    <div className="max-w-3xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-white">Register New Evidence</h1>
        <p className="text-slate-400">
          Upload and register digital evidence to the blockchain
        </p>
      </div>

      <form onSubmit={handleSubmit} className="space-y-6">
        {/* File Upload */}
        <div className="bg-slate-800 rounded-xl border border-slate-700 p-6">
          <h2 className="text-lg font-semibold text-white mb-4">Evidence File</h2>
          
          {!file ? (
            <div
              {...getRootProps()}
              className={`border-2 border-dashed rounded-xl p-8 text-center cursor-pointer transition-colors ${
                isDragActive
                  ? 'border-blue-500 bg-blue-500/10'
                  : 'border-slate-600 hover:border-slate-500'
              }`}
            >
              <input {...getInputProps()} />
              <CloudArrowUpIcon className="h-12 w-12 text-slate-500 mx-auto mb-4" />
              <p className="text-slate-300 mb-2">
                {isDragActive
                  ? 'Drop the file here...'
                  : 'Drag and drop evidence file here, or click to select'}
              </p>
              <p className="text-sm text-slate-500">
                Maximum file size: 100MB
              </p>
            </div>
          ) : (
            <div className="flex items-center justify-between p-4 bg-slate-900/50 rounded-lg">
              <div className="flex items-center space-x-4">
                <div className="p-3 bg-blue-500/20 rounded-lg">
                  <DocumentIcon className="h-8 w-8 text-blue-500" />
                </div>
                <div>
                  <p className="text-white font-medium">{file.name}</p>
                  <p className="text-sm text-slate-400">
                    {formatSize(file.size)} • {file.type || 'Unknown type'}
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={removeFile}
                className="p-2 text-slate-400 hover:text-red-400 transition-colors"
              >
                <XMarkIcon className="h-5 w-5" />
              </button>
            </div>
          )}
        </div>

        {/* Evidence Details */}
        <div className="bg-slate-800 rounded-xl border border-slate-700 p-6">
          <h2 className="text-lg font-semibold text-white mb-4">Evidence Details</h2>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div className="md:col-span-2">
              <label className="block text-sm text-slate-400 mb-1">
                Case ID <span className="text-red-400">*</span>
              </label>
              <input
                type="text"
                name="caseId"
                value={formData.caseId}
                onChange={handleInputChange}
                placeholder="e.g., CASE-2024-001"
                className="w-full px-4 py-2.5 bg-slate-700/50 border border-slate-600 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
                required
              />
            </div>

            <div className="md:col-span-2">
              <label className="block text-sm text-slate-400 mb-1">
                Evidence Name
              </label>
              <input
                type="text"
                name="name"
                value={formData.name}
                onChange={handleInputChange}
                placeholder="Descriptive name for the evidence"
                className="w-full px-4 py-2.5 bg-slate-700/50 border border-slate-600 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div>
              <label className="block text-sm text-slate-400 mb-1">
                Evidence Type
              </label>
              <select
                name="type"
                value={formData.type}
                onChange={handleInputChange}
                className="w-full px-4 py-2.5 bg-slate-700/50 border border-slate-600 rounded-lg text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
                {evidenceTypes.map(type => (
                  <option key={type} value={type}>{type}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-sm text-slate-400 mb-1">
                Source Device
              </label>
              <input
                type="text"
                name="sourceDevice"
                value={formData.sourceDevice}
                onChange={handleInputChange}
                placeholder="e.g., Dell Laptop SN: ABC123"
                className="w-full px-4 py-2.5 bg-slate-700/50 border border-slate-600 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div className="md:col-span-2">
              <label className="block text-sm text-slate-400 mb-1">
                Acquisition Location
              </label>
              <input
                type="text"
                name="location"
                value={formData.location}
                onChange={handleInputChange}
                placeholder="Where was this evidence acquired?"
                className="w-full px-4 py-2.5 bg-slate-700/50 border border-slate-600 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
            </div>

            <div className="md:col-span-2">
              <label className="block text-sm text-slate-400 mb-1">
                Notes
              </label>
              <textarea
                name="notes"
                value={formData.notes}
                onChange={handleInputChange}
                placeholder="Additional notes about the evidence..."
                rows={4}
                className="w-full px-4 py-2.5 bg-slate-700/50 border border-slate-600 rounded-lg text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
              />
            </div>
          </div>
        </div>

        {/* Info Box */}
        <div className="bg-blue-500/10 border border-blue-500/30 rounded-xl p-4">
          <p className="text-sm text-blue-300">
            <strong>Note:</strong> The evidence file will be encrypted and stored on IPFS. 
            A cryptographic hash will be computed and stored on the blockchain to ensure integrity.
            This creates an immutable record of the evidence registration.
          </p>
        </div>

        {/* Submit */}
        <div className="flex justify-end space-x-4">
          <button
            type="button"
            onClick={() => navigate('/evidence')}
            className="px-6 py-2.5 bg-slate-700 hover:bg-slate-600 text-white rounded-lg transition-colors"
          >
            Cancel
          </button>
          <button
            type="submit"
            disabled={loading || !file}
            className="px-6 py-2.5 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-600/50 text-white rounded-lg transition-colors flex items-center"
          >
            {loading ? (
              <>
                <div className="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent mr-2" />
                Registering...
              </>
            ) : (
              'Register Evidence'
            )}
          </button>
        </div>
      </form>
    </div>
  );
};

export default RegisterEvidence;

