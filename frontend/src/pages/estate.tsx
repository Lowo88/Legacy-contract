import React, { useState } from 'react';
import Layout from '../components/Layout';

const EstatePlanning: React.FC = () => {
  const [activeTab, setActiveTab] = useState('overview');

  const tabs = [
    { id: 'overview', label: 'Estate Overview' },
    { id: 'plan', label: 'Create Plan' },
    { id: 'documents', label: 'Documents' },
  ];

  const estatePlans = [
    {
      id: 1,
      name: 'Main Estate Plan',
      status: 'Active',
      lastUpdated: '1 week ago',
      assets: '$2,000,000',
      heirs: 4,
      documents: 3,
    },
    {
      id: 2,
      name: 'Charitable Trust',
      status: 'Active',
      lastUpdated: '2 weeks ago',
      assets: '$500,000',
      heirs: 1,
      documents: 2,
    },
  ];

  return (
    <Layout>
      <div className="space-y-8">
        <div className="flex justify-between items-center">
          <h1 className="text-3xl font-bold text-gold-500">Estate Planning</h1>
          <button className="gold-button">Create New Plan</button>
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

        {/* Estate Overview */}
        {activeTab === 'overview' && (
          <div className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div className="card">
                <h3 className="text-xl font-semibold text-gold-500">Total Plans</h3>
                <p className="text-3xl font-bold text-white">2</p>
              </div>
              <div className="card">
                <h3 className="text-xl font-semibold text-gold-500">Total Assets</h3>
                <p className="text-3xl font-bold text-white">$2,500,000</p>
              </div>
              <div className="card">
                <h3 className="text-xl font-semibold text-gold-500">Total Documents</h3>
                <p className="text-3xl font-bold text-white">5</p>
              </div>
            </div>

            <div className="card">
              <h2 className="section-title">Estate Plans</h2>
              <div className="space-y-4">
                {estatePlans.map((plan) => (
                  <div key={plan.id} className="p-4 bg-[#1a1a1a] rounded">
                    <div className="flex justify-between items-start">
                      <div>
                        <h3 className="text-xl font-semibold text-gold-500">{plan.name}</h3>
                        <div className="flex space-x-4 mt-2">
                          <span className="text-white">Status: {plan.status}</span>
                          <span className="text-white">Assets: {plan.assets}</span>
                          <span className="text-white">Heirs: {plan.heirs}</span>
                          <span className="text-white">Documents: {plan.documents}</span>
                        </div>
                        <p className="text-gray-400 text-sm mt-2">Last updated: {plan.lastUpdated}</p>
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

        {/* Create Plan */}
        {activeTab === 'plan' && (
          <div className="card">
            <h2 className="section-title">Create Estate Plan</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-white mb-2">Plan Name</label>
                <input type="text" className="input-field" placeholder="Enter plan name" />
              </div>
              <div>
                <label className="block text-white mb-2">Plan Type</label>
                <select className="input-field">
                  <option value="main">Main Estate Plan</option>
                  <option value="charitable">Charitable Trust</option>
                  <option value="special">Special Purpose Trust</option>
                </select>
              </div>
              <div>
                <label className="block text-white mb-2">Asset Allocation</label>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-white">Main Vault</span>
                    <input type="number" className="input-field w-32" placeholder="Amount" />
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-white">Emergency Fund</span>
                    <input type="number" className="input-field w-32" placeholder="Amount" />
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-white">Charitable Trust</span>
                    <input type="number" className="input-field w-32" placeholder="Amount" />
                  </div>
                </div>
              </div>
              <div>
                <label className="block text-white mb-2">Heir Distribution</label>
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-white">Primary Heir</span>
                    <input type="number" className="input-field w-32" placeholder="Percentage" />
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-white">Secondary Heir</span>
                    <input type="number" className="input-field w-32" placeholder="Percentage" />
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-white">Charitable</span>
                    <input type="number" className="input-field w-32" placeholder="Percentage" />
                  </div>
                </div>
              </div>
              <div>
                <label className="block text-white mb-2">Additional Settings</label>
                <div className="space-y-2">
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Enable AI Agent</label>
                  </div>
                  <div className="flex items-center">
                    <input type="checkbox" className="h-5 w-5 text-gold-500" />
                    <label className="text-white ml-2">Enable Dead Man's Switch</label>
                  </div>
                </div>
              </div>
              <div className="flex justify-end">
                <button className="gold-button">Create Plan</button>
              </div>
            </div>
          </div>
        )}

        {/* Documents */}
        {activeTab === 'documents' && (
          <div className="card">
            <h2 className="section-title">Estate Documents</h2>
            <div className="space-y-4">
              <div className="p-4 bg-[#1a1a1a] rounded">
                <div className="flex justify-between items-center">
                  <div>
                    <h3 className="text-xl font-semibold text-gold-500">Last Will and Testament</h3>
                    <p className="text-white">Last updated: 1 week ago</p>
                  </div>
                  <div className="flex space-x-2">
                    <button className="text-gold-500 hover:text-gold-400">View</button>
                    <button className="text-gold-500 hover:text-gold-400">Edit</button>
                  </div>
                </div>
              </div>
              <div className="p-4 bg-[#1a1a1a] rounded">
                <div className="flex justify-between items-center">
                  <div>
                    <h3 className="text-xl font-semibold text-gold-500">Trust Agreement</h3>
                    <p className="text-white">Last updated: 2 weeks ago</p>
                  </div>
                  <div className="flex space-x-2">
                    <button className="text-gold-500 hover:text-gold-400">View</button>
                    <button className="text-gold-500 hover:text-gold-400">Edit</button>
                  </div>
                </div>
              </div>
              <div className="p-4 bg-[#1a1a1a] rounded">
                <div className="flex justify-between items-center">
                  <div>
                    <h3 className="text-xl font-semibold text-gold-500">Asset Inventory</h3>
                    <p className="text-white">Last updated: 3 days ago</p>
                  </div>
                  <div className="flex space-x-2">
                    <button className="text-gold-500 hover:text-gold-400">View</button>
                    <button className="text-gold-500 hover:text-gold-400">Edit</button>
                  </div>
                </div>
              </div>
              <div className="flex justify-end">
                <button className="gold-button">Add Document</button>
              </div>
            </div>
          </div>
        )}
      </div>
    </Layout>
  );
};

export default EstatePlanning; 