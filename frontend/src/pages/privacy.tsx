import React, { useState } from 'react';
import Layout from '../components/Layout';

const PrivacyManagement: React.FC = () => {
  const [encryptionSettings, setEncryptionSettings] = useState({
    encryptAllData: true,
    autoShareWithHeirs: false,
    allowKnowledgeTransfer: true,
  });

  const [accessControl, setAccessControl] = useState({
    heirAccess: true,
    publicAccess: false,
    customAccess: false,
  });

  const [knowledgeSharing, setKnowledgeSharing] = useState({
    allowSharing: true,
    requireApproval: true,
    shareWithTrusted: true,
  });

  const [privacyPreferences, setPrivacyPreferences] = useState({
    hideSensitiveData: true,
    encryptPersonalInfo: true,
    secureTransactions: true,
  });

  return (
    <Layout>
      <div className="space-y-8">
        <h1 className="text-3xl font-bold text-gold-500 mb-8">Privacy Management</h1>

        {/* Encryption Settings */}
        <section className="card">
          <h2 className="section-title">Encryption Settings</h2>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <label className="text-white">Encrypt All Data</label>
              <input
                type="checkbox"
                checked={encryptionSettings.encryptAllData}
                onChange={(e) => setEncryptionSettings({ ...encryptionSettings, encryptAllData: e.target.checked })}
                className="h-5 w-5 text-gold-500"
              />
            </div>
            <div className="flex items-center justify-between">
              <label className="text-white">Auto Share with Heirs</label>
              <input
                type="checkbox"
                checked={encryptionSettings.autoShareWithHeirs}
                onChange={(e) => setEncryptionSettings({ ...encryptionSettings, autoShareWithHeirs: e.target.checked })}
                className="h-5 w-5 text-gold-500"
              />
            </div>
            <div className="flex items-center justify-between">
              <label className="text-white">Allow Knowledge Transfer</label>
              <input
                type="checkbox"
                checked={encryptionSettings.allowKnowledgeTransfer}
                onChange={(e) => setEncryptionSettings({ ...encryptionSettings, allowKnowledgeTransfer: e.target.checked })}
                className="h-5 w-5 text-gold-500"
              />
            </div>
          </div>
        </section>

        {/* Access Control */}
        <section className="card">
          <h2 className="section-title">Access Control</h2>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <label className="text-white">Heir Access</label>
              <input
                type="checkbox"
                checked={accessControl.heirAccess}
                onChange={(e) => setAccessControl({ ...accessControl, heirAccess: e.target.checked })}
                className="h-5 w-5 text-gold-500"
              />
            </div>
            <div className="flex items-center justify-between">
              <label className="text-white">Public Access</label>
              <input
                type="checkbox"
                checked={accessControl.publicAccess}
                onChange={(e) => setAccessControl({ ...accessControl, publicAccess: e.target.checked })}
                className="h-5 w-5 text-gold-500"
              />
            </div>
            <div className="flex items-center justify-between">
              <label className="text-white">Custom Access</label>
              <input
                type="checkbox"
                checked={accessControl.customAccess}
                onChange={(e) => setAccessControl({ ...accessControl, customAccess: e.target.checked })}
                className="h-5 w-5 text-gold-500"
              />
            </div>
          </div>
        </section>

        {/* Knowledge Sharing Permissions */}
        <section className="card">
          <h2 className="section-title">Knowledge Sharing Permissions</h2>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <label className="text-white">Allow Sharing</label>
              <input
                type="checkbox"
                checked={knowledgeSharing.allowSharing}
                onChange={(e) => setKnowledgeSharing({ ...knowledgeSharing, allowSharing: e.target.checked })}
                className="h-5 w-5 text-gold-500"
              />
            </div>
            <div className="flex items-center justify-between">
              <label className="text-white">Require Approval</label>
              <input
                type="checkbox"
                checked={knowledgeSharing.requireApproval}
                onChange={(e) => setKnowledgeSharing({ ...knowledgeSharing, requireApproval: e.target.checked })}
                className="h-5 w-5 text-gold-500"
              />
            </div>
            <div className="flex items-center justify-between">
              <label className="text-white">Share with Trusted</label>
              <input
                type="checkbox"
                checked={knowledgeSharing.shareWithTrusted}
                onChange={(e) => setKnowledgeSharing({ ...knowledgeSharing, shareWithTrusted: e.target.checked })}
                className="h-5 w-5 text-gold-500"
              />
            </div>
          </div>
        </section>

        {/* Privacy Preferences */}
        <section className="card">
          <h2 className="section-title">Privacy Preferences</h2>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <label className="text-white">Hide Sensitive Data</label>
              <input
                type="checkbox"
                checked={privacyPreferences.hideSensitiveData}
                onChange={(e) => setPrivacyPreferences({ ...privacyPreferences, hideSensitiveData: e.target.checked })}
                className="h-5 w-5 text-gold-500"
              />
            </div>
            <div className="flex items-center justify-between">
              <label className="text-white">Encrypt Personal Info</label>
              <input
                type="checkbox"
                checked={privacyPreferences.encryptPersonalInfo}
                onChange={(e) => setPrivacyPreferences({ ...privacyPreferences, encryptPersonalInfo: e.target.checked })}
                className="h-5 w-5 text-gold-500"
              />
            </div>
            <div className="flex items-center justify-between">
              <label className="text-white">Secure Transactions</label>
              <input
                type="checkbox"
                checked={privacyPreferences.secureTransactions}
                onChange={(e) => setPrivacyPreferences({ ...privacyPreferences, secureTransactions: e.target.checked })}
                className="h-5 w-5 text-gold-500"
              />
            </div>
          </div>
        </section>

        <div className="flex justify-end">
          <button className="gold-button">
            Save Privacy Settings
          </button>
        </div>
      </div>
    </Layout>
  );
};

export default PrivacyManagement; 