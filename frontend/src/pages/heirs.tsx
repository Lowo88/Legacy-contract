import React, { useState } from 'react';
import Layout from '../components/Layout';

const Heirs: React.FC = () => {
  const [activeTab, setActiveTab] = useState('overview');

  const tabs = [
    { id: 'overview', label: 'Heir Overview' },
    { id: 'add', label: 'Add Heir' },
    { id: 'permissions', label: 'Permissions' },
  ];

  const heirs = [
    {
      id: 1,
      name: 'John Doe',
      address: '0x1234...5678',
      role: 'Primary Heir',
      accessLevel: 'Full',
      assets: '$500,000',
      lastActive: '2 days ago',
    },
    {
      id: 2,
      name: 'Jane Smith',
      address: '0x8765...4321',
      role: 'Secondary Heir',
      accessLevel: 'Limited',
      assets: '$250,000',
      lastActive: '1 week ago',
    },
    {
      id: 3,
      name: 'Charity Fund',
      address: '0xabcd...efgh',
      role: 'Charitable',
      accessLevel: 'Restricted',
      assets: '$100,000',
      lastActive: '1 month ago',
    },
  ];

  return (
    <Layout>
      <div className="space-y-8">
        <div className="flex justify-between items-center">
          <h1 className="text-3xl font-bold text-gold-500">Heir Management</h1>
          <button className="gold-button">Add New Heir</button>
        </div>

        {/* Tabs */}
        <div className="flex space-x-4 border-b border-gold-500">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`px-4 py-2 ${
                activeTab === tab.id
                  ? 'text-gold-500 border-b-2 border-gold-500'
                  : 'text-white hover:text-gold-500'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Heir Overview */}
        {activeTab === 'overview' && (
          <div className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="card">
                <h3 className="text-xl font-semibold text-gold-500">Total Heirs</h3>
                <p className="text-3xl font-bold text-white">3</p>
              </div>
              <div className="card">
                <h3 className="text-xl font-semibold text-gold-500">Active Heirs</h3>
                <p className="text-3xl font-bold text-white">2</p>
              </div>
              <div className="card">
                <h3 className="text-xl font-semibold text-gold-500">Total Assets</h3>
                <p className="text-3xl font-bold text-white">$850,000</p>
              </div>
            </div>

            <div className="card">
              <h2 className="section-title">Heir List</h2>
              <div className="space-y-4">
                {heirs.map((heir) => (
                  <div key={heir.id} className="p-4 bg-[#1a1a1a] rounded">
                    <div className="flex justify-between items-start">
                      <div>
                        <h3 className="text-xl font-semibold text-gold-500">{heir.name}</h3>
                        <div className="flex space-x-4 mt-2">
                          <span className="text-white">Role: {heir.role}</span>
                          <span className="text-white">Access: {heir.accessLevel}</span>
                          <span className="text-white">Assets: {heir.assets}</span>
                        </div>
                        <p className="text-gray-400 text-sm mt-2">Last active: {heir.lastActive}</p>
                        <p className="text-gray-400 text-sm">Address: {heir.address}</p>
                      </div>
                      <div className="flex space-x-2">
                        <button className="text-gold-500 hover:text-gold-400">Edit</button>
                        <button className="text-red-500 hover:text-red-400">Remove</button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Add Heir */}
        {activeTab === 'add' && (
          <div className="card">
            <h2 className="section-title">Add New Heir</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-white mb-2">Heir Name</label>
                <input type="text" className="input-field" placeholder="Enter heir name" />
              </div>
              <div>
                <label className="block text-white mb-2">Wallet Address</label>
                <input type="text" className="input-field" placeholder="Enter wallet address" />
              </div>
              <div>
                <label className="block text-white mb-2">Role</label>
                <select className="input-field">
                  <option value="primary">Primary Heir</option>
                  <option value="secondary">Secondary Heir</option>
                  <option value="charitable">Charitable</option>
                </select>
              </div>
              <div>
                <label className="block text-white mb-2">Access Level</label>
                <select className="input-field">
                  <option value="full">Full Access</option>
                  <option value="limited">Limited Access</option>
                  <option value="restricted">Restricted Access</option>
                </select>
              </div>
              <div>
                <label className="block text-white mb-2">Asset Allocation</label>
                <input type="number" className="input-field" placeholder="Enter amount" />
              </div>
              <div>
                <label className="block text-white mb-2">Additional Settings</label>
                <div className="space-y-2">
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Enable Notifications</label>
                  </div>
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Require Verification</label>
                  </div>
                </div>
              </div>
              <div className="flex justify-end">
                <button className="gold-button">Add Heir</button>
              </div>
            </div>
          </div>
        )}

        {/* Permissions */}
        {activeTab === 'permissions' && (
          <div className="card">
            <h2 className="section-title">Permission Settings</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-white mb-2">Default Access Level</label>
                <select className="input-field">
                  <option value="full">Full Access</option>
                  <option value="limited">Limited Access</option>
                  <option value="restricted">Restricted Access</option>
                </select>
              </div>
              <div>
                <label className="block text-white mb-2">Verification Requirements</label>
                <div className="space-y-2">
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Require KYC</label>
                  </div>
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Require 2FA</label>
                  </div>
                </div>
              </div>
              <div>
                <label className="block text-white mb-2">Access Control</label>
                <div className="space-y-2">
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Enable Time-based Access</label>
                  </div>
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Enable Location-based Access</label>
                  </div>
                </div>
              </div>
              <div className="flex justify-end">
                <button className="gold-button">Save Permissions</button>
              </div>
            </div>
          </div>
        )}
      </div>
    </Layout>
  );
};

export default Heirs; 