import React from 'react';
import Layout from '../components/Layout';
import Link from 'next/link';

const Dashboard: React.FC = () => {
  const features = [
    {
      title: 'Vault Management',
      description: 'Manage your digital assets and inheritance vaults',
      icon: '🔒',
      path: '/vaults',
    },
    {
      title: 'Asset Overview',
      description: 'View and manage all your digital assets',
      icon: '💰',
      path: '/assets',
    },
    {
      title: 'Heir Management',
      description: 'Manage heirs and their access permissions',
      icon: '👥',
      path: '/heirs',
    },
    {
      title: 'Estate Planning',
      description: 'Plan and manage your digital estate',
      icon: '📝',
      path: '/estate',
    },
    {
      title: 'Privacy Management',
      description: 'Control your privacy settings and encryption',
      icon: '🔐',
      path: '/privacy',
    },
    {
      title: 'AI Agent',
      description: 'Access your AI assistant and learning history',
      icon: '🤖',
      path: '/ai-agent',
    },
  ];

  return (
    <Layout>
      <div className="space-y-8">
        <div className="flex justify-between items-center">
          <h1 className="text-3xl font-bold text-gold-500">Dashboard</h1>
          <div className="flex space-x-4">
            <button className="gold-button">Quick Actions</button>
            <button className="gold-button">Settings</button>
          </div>
        </div>

        {/* Quick Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div className="card">
            <h3 className="text-xl font-semibold text-gold-500">Total Assets</h3>
            <p className="text-3xl font-bold text-white">$1,234,567</p>
          </div>
          <div className="card">
            <h3 className="text-xl font-semibold text-gold-500">Active Vaults</h3>
            <p className="text-3xl font-bold text-white">3</p>
          </div>
          <div className="card">
            <h3 className="text-xl font-semibold text-gold-500">Heirs</h3>
            <p className="text-3xl font-bold text-white">5</p>
          </div>
        </div>

        {/* Features Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((feature) => (
            <Link
              key={feature.path}
              href={feature.path}
              className="card hover:border-gold-500 transition-all duration-300"
            >
              <div className="flex items-center space-x-4">
                <span className="text-3xl">{feature.icon}</span>
                <div>
                  <h3 className="text-xl font-semibold text-gold-500">{feature.title}</h3>
                  <p className="text-white">{feature.description}</p>
                </div>
              </div>
            </Link>
          ))}
        </div>

        {/* Recent Activity */}
        <section className="card">
          <h2 className="section-title">Recent Activity</h2>
          <div className="space-y-4">
            <div className="flex items-center justify-between p-4 bg-[#1a1a1a] rounded">
              <div className="flex items-center space-x-4">
                <span className="text-gold-500">🔒</span>
                <div>
                  <p className="text-white">New vault created</p>
                  <p className="text-gray-400 text-sm">2 hours ago</p>
                </div>
              </div>
              <button className="text-gold-500 hover:text-gold-400">View</button>
            </div>
            <div className="flex items-center justify-between p-4 bg-[#1a1a1a] rounded">
              <div className="flex items-center space-x-4">
                <span className="text-gold-500">👥</span>
                <div>
                  <p className="text-white">Heir access updated</p>
                  <p className="text-gray-400 text-sm">5 hours ago</p>
                </div>
              </div>
              <button className="text-gold-500 hover:text-gold-400">View</button>
            </div>
          </div>
        </section>
      </div>
    </Layout>
  );
};

export default Dashboard; 