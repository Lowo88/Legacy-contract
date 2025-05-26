import React, { useState } from 'react';
import Layout from '../components/Layout';

const Vaults: React.FC = () => {
  const [activeTab, setActiveTab] = useState('overview');

  const tabs = [
    { id: 'overview', label: 'Vault Overview' },
    { id: 'create', label: 'Create Vault' },
    { id: 'settings', label: 'Vault Settings' },
  ];

  const vaults = [
    {
      id: 1,
      name: 'Main Inheritance Vault',
      type: 'Private',
      status: 'Active',
      assets: '$1,000,000',
      heirs: 3,
      lastUpdated: '2 days ago',
    },
    {
      id: 2,
      name: 'Emergency Fund',
      type: 'Regular',
      status: 'Active',
      assets: '$500,000',
      heirs: 2,
      lastUpdated: '1 week ago',
    },
    {
      id: 3,
      name: 'Charitable Trust',
      type: 'Private',
      status: 'Active',
      assets: '$250,000',
      heirs: 1,
      lastUpdated: '3 days ago',
    },
  ];

  return (
    <Layout>
      <div className="space-y-8">
        <div className="flex justify-between items-center">
          <h1 className="text-3xl font-bold text-gold-500">Vault Management</h1>
          <button className="gold-button">Create New Vault</button>
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

        {/* Vault Overview */}
        {activeTab === 'overview' && (
          <div className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="card">
                <h3 className="text-xl font-semibold text-gold-500">Total Vaults</h3>
                <p className="text-3xl font-bold text-white">3</p>
              </div>
              <div className="card">
                <h3 className="text-xl font-semibold text-gold-500">Total Assets</h3>
                <p className="text-3xl font-bold text-white">$1,750,000</p>
              </div>
              <div className="card">
                <h3 className="text-xl font-semibold text-gold-500">Active Heirs</h3>
                <p className="text-3xl font-bold text-white">6</p>
              </div>
            </div>

            <div className="card">
              <h2 className="section-title">Your Vaults</h2>
              <div className="space-y-4">
                {vaults.map((vault) => (
                  <div key={vault.id} className="p-4 bg-[#1a1a1a] rounded">
                    <div className="flex justify-between items-start">
                      <div>
                        <h3 className="text-xl font-semibold text-gold-500">{vault.name}</h3>
                        <div className="flex space-x-4 mt-2">
                          <span className="text-white">Type: {vault.type}</span>
                          <span className="text-white">Status: {vault.status}</span>
                          <span className="text-white">Assets: {vault.assets}</span>
                          <span className="text-white">Heirs: {vault.heirs}</span>
                        </div>
                        <p className="text-gray-400 text-sm mt-2">Last updated: {vault.lastUpdated}</p>
                      </div>
                      <div className="flex space-x-2">
                        <button className="text-gold-500 hover:text-gold-400">View</button>
                        <button className="text-gold-500 hover:text-gold-400">Edit</button>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {/* Create Vault */}
        {activeTab === 'create' && (
          <div className="card">
            <h2 className="section-title">Create New Vault</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-white mb-2">Vault Name</label>
                <input type="text" className="input-field" placeholder="Enter vault name" />
              </div>
              <div>
                <label className="block text-white mb-2">Vault Type</label>
                <select className="input-field">
                  <option value="regular">Regular Vault</option>
                  <option value="private">Private Vault</option>
                </select>
              </div>
              <div>
                <label className="block text-white mb-2">Initial Deposit</label>
                <input type="number" className="input-field" placeholder="Enter amount" />
              </div>
              <div>
                <label className="block text-white mb-2">Heirs</label>
                <input type="text" className="input-field" placeholder="Enter heir addresses (comma separated)" />
              </div>
              <div>
                <label className="block text-white mb-2">Access Settings</label>
                <div className="space-y-2">
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Enable Dead Man's Switch</label>
                  </div>
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Enable AI Agent</label>
                  </div>
                </div>
              </div>
              <div className="flex justify-end">
                <button className="gold-button">Create Vault</button>
              </div>
            </div>
          </div>
        )}

        {/* Vault Settings */}
        {activeTab === 'settings' && (
          <div className="card">
            <h2 className="section-title">Vault Settings</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-white mb-2">Default Vault</label>
                <select className="input-field">
                  <option value="main">Main Inheritance Vault</option>
                  <option value="emergency">Emergency Fund</option>
                  <option value="charitable">Charitable Trust</option>
                </select>
              </div>
              <div>
                <label className="block text-white mb-2">Auto-Transfer Settings</label>
                <div className="space-y-2">
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Enable Auto-Transfer</label>
                  </div>
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Enable Notifications</label>
                  </div>
                </div>
              </div>
              <div>
                <label className="block text-white mb-2">Security Settings</label>
                <div className="space-y-2">
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Enable 2FA</label>
                  </div>
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Enable IP Whitelist</label>
                  </div>
                </div>
              </div>
              <div className="flex justify-end">
                <button className="gold-button">Save Settings</button>
              </div>
            </div>
          </div>
        )}
      </div>
    </Layout>
  );
};

export default Vaults; 