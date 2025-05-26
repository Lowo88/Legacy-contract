import React, { useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/router';
import { ethers } from 'ethers';

const Layout: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [isConnected, setIsConnected] = useState(false);
  const [account, setAccount] = useState<string | null>(null);
  const router = useRouter();

  const connectWallet = async () => {
    if (window.ethereum) {
      try {
        const provider = new ethers.providers.Web3Provider(window.ethereum);
        await provider.send("eth_requestAccounts", []);
        const signer = provider.getSigner();
        const address = await signer.getAddress();
        setAccount(address);
        setIsConnected(true);
      } catch (error) {
        console.error("Error connecting to MetaMask:", error);
      }
    } else {
      alert("Please install MetaMask!");
    }
  };

  const navItems = [
    { name: 'Dashboard', path: '/dashboard' },
    { name: 'Vault Management', path: '/vaults' },
    { name: 'Asset Overview', path: '/assets' },
    { name: 'Heir Management', path: '/heirs' },
    { name: 'Estate Planning', path: '/estate' },
    { name: 'Privacy Management', path: '/privacy' },
    { name: 'AI Agent', path: '/ai-agent' },
  ];

  return (
    <div className="min-h-screen bg-black">
      <nav className="bg-[#1a1a1a] border-b border-gold-500 p-4">
        <div className="container mx-auto flex justify-between items-center">
          <div className="flex items-center space-x-8">
            <Link href="/" className="text-2xl font-bold text-gold-500">
              Legacy Protocol
            </Link>
            <div className="hidden md:flex space-x-4">
              {navItems.map((item) => (
                <Link
                  key={item.path}
                  href={item.path}
                  className={`nav-link ${
                    router.pathname === item.path ? 'bg-gold-500 text-black' : ''
                  }`}
                >
                  {item.name}
                </Link>
              ))}
            </div>
          </div>
          <div>
            {!isConnected ? (
              <button
                onClick={connectWallet}
                className="gold-button"
              >
                Connect Wallet
              </button>
            ) : (
              <div className="flex items-center space-x-4">
                <span className="text-white">
                  {account?.slice(0, 6)}...{account?.slice(-4)}
                </span>
              </div>
            )}
          </div>
        </div>
      </nav>

      <main className="container mx-auto p-4">
        <div className="gold-frame">
          {children}
        </div>
      </main>

      <footer className="bg-[#1a1a1a] border-t border-gold-500 p-4 mt-8">
        <div className="container mx-auto text-center text-white">
          © 2024 Legacy Protocol. All rights reserved.
        </div>
      </footer>
    </div>
  );
};

export default Layout; 