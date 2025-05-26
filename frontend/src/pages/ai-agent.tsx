import React, { useState } from 'react';
import Layout from '../components/Layout';

const AIAgent: React.FC = () => {
  const [activeTab, setActiveTab] = useState('learning');

  const tabs = [
    { id: 'learning', label: 'Learning History' },
    { id: 'knowledge', label: 'Knowledge Base' },
    { id: 'recommendations', label: 'Recommendations' },
    { id: 'expertise', label: 'Expertise Tracking' },
  ];

  return (
    <Layout>
      <div className="space-y-8">
        <div className="flex justify-between items-center">
          <h1 className="text-3xl font-bold text-gold-500">AI Agent Interface</h1>
          <div className="flex space-x-4">
            <button className="gold-button">New Learning Session</button>
            <button className="gold-button">Ask AI</button>
          </div>
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

        {/* Learning History */}
        {activeTab === 'learning' && (
          <div className="space-y-4">
            <div className="card">
              <h2 className="section-title">Recent Learning Sessions</h2>
              <div className="space-y-4">
                <div className="p-4 bg-[#1a1a1a] rounded">
                  <div className="flex justify-between items-start">
                    <div>
                      <h3 className="text-xl font-semibold text-gold-500">Estate Planning Basics</h3>
                      <p className="text-white">Completed: 2 days ago</p>
                      <p className="text-white mt-2">Comprehension Score: 95%</p>
                    </div>
                    <button className="text-gold-500 hover:text-gold-400">View Details</button>
                  </div>
                </div>
                <div className="p-4 bg-[#1a1a1a] rounded">
                  <div className="flex justify-between items-start">
                    <div>
                      <h3 className="text-xl font-semibold text-gold-500">Asset Management</h3>
                      <p className="text-white">Completed: 5 days ago</p>
                      <p className="text-white mt-2">Comprehension Score: 88%</p>
                    </div>
                    <button className="text-gold-500 hover:text-gold-400">View Details</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Knowledge Base */}
        {activeTab === 'knowledge' && (
          <div className="space-y-4">
            <div className="card">
              <h2 className="section-title">Knowledge Categories</h2>
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <div className="p-4 bg-[#1a1a1a] rounded">
                  <h3 className="text-xl font-semibold text-gold-500">Estate Planning</h3>
                  <p className="text-white">15 articles</p>
                  <p className="text-white">Last updated: 3 days ago</p>
                </div>
                <div className="p-4 bg-[#1a1a1a] rounded">
                  <h3 className="text-xl font-semibold text-gold-500">Asset Management</h3>
                  <p className="text-white">12 articles</p>
                  <p className="text-white">Last updated: 1 week ago</p>
                </div>
                <div className="p-4 bg-[#1a1a1a] rounded">
                  <h3 className="text-xl font-semibold text-gold-500">Legal Framework</h3>
                  <p className="text-white">8 articles</p>
                  <p className="text-white">Last updated: 2 weeks ago</p>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Recommendations */}
        {activeTab === 'recommendations' && (
          <div className="space-y-4">
            <div className="card">
              <h2 className="section-title">AI Recommendations</h2>
              <div className="space-y-4">
                <div className="p-4 bg-[#1a1a1a] rounded">
                  <div className="flex justify-between items-start">
                    <div>
                      <h3 className="text-xl font-semibold text-gold-500">Asset Diversification</h3>
                      <p className="text-white">Priority: High</p>
                      <p className="text-white mt-2">Suggested action: Review and rebalance portfolio</p>
                    </div>
                    <button className="gold-button">Implement</button>
                  </div>
                </div>
                <div className="p-4 bg-[#1a1a1a] rounded">
                  <div className="flex justify-between items-start">
                    <div>
                      <h3 className="text-xl font-semibold text-gold-500">Heir Education</h3>
                      <p className="text-white">Priority: Medium</p>
                      <p className="text-white mt-2">Suggested action: Schedule training session</p>
                    </div>
                    <button className="gold-button">Implement</button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Expertise Tracking */}
        {activeTab === 'expertise' && (
          <div className="space-y-4">
            <div className="card">
              <h2 className="section-title">Expertise Areas</h2>
              <div className="space-y-4">
                <div className="p-4 bg-[#1a1a1a] rounded">
                  <div className="flex justify-between items-center">
                    <div>
                      <h3 className="text-xl font-semibold text-gold-500">Estate Planning</h3>
                      <p className="text-white">Expertise Level: 85%</p>
                    </div>
                    <div className="w-32 h-2 bg-gray-700 rounded-full">
                      <div className="h-full bg-gold-500 rounded-full" style={{ width: '85%' }}></div>
                    </div>
                  </div>
                </div>
                <div className="p-4 bg-[#1a1a1a] rounded">
                  <div className="flex justify-between items-center">
                    <div>
                      <h3 className="text-xl font-semibold text-gold-500">Asset Management</h3>
                      <p className="text-white">Expertise Level: 75%</p>
                    </div>
                    <div className="w-32 h-2 bg-gray-700 rounded-full">
                      <div className="h-full bg-gold-500 rounded-full" style={{ width: '75%' }}></div>
                    </div>
                  </div>
                </div>
                <div className="p-4 bg-[#1a1a1a] rounded">
                  <div className="flex justify-between items-center">
                    <div>
                      <h3 className="text-xl font-semibold text-gold-500">Legal Framework</h3>
                      <p className="text-white">Expertise Level: 60%</p>
                    </div>
                    <div className="w-32 h-2 bg-gray-700 rounded-full">
                      <div className="h-full bg-gold-500 rounded-full" style={{ width: '60%' }}></div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </Layout>
  );
};

export default AIAgent; 