# Legacy Contract

A Privacy-Preserving Smart Contract for Digital Asset Inheritance

[![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.0-blue)](https://soliditylang.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Security: Audited](https://img.shields.io/badge/Security-Pending%20Audit-yellow)](SECURITY.md)
[![Test Coverage](https://img.shields.io/badge/Coverage-Pending-yellow)](TESTS.md)

## 🚨 Security Notice

This project is currently in development and **HAS NOT BEEN AUDITED**. Do not use in production or with real assets until:
- Full security audit is completed
- Test coverage reaches >95%
- Bug bounty program is established
- Community review period is completed

## 📖 Overview

A Solidity-based smart contract enabling secure and private inheritance of digital assets using zero-knowledge proofs (Halo2). This project aims to solve the critical problem of digital asset succession while maintaining privacy and security.

### Key Features

- 🔐 Private vault management with time-locked assets
- 👥 Multi-signature emergency access system
- 🛡️ Zero-knowledge proof integration using Halo2
- 📋 Customizable inheritance templates
- ⏰ Time-based access controls
- 🔄 Asset health monitoring
- 📱 Mobile-friendly interface (coming soon)

## 🏗️ Architecture

```
contracts/
├── core/
│   ├── Legacy.sol         # Main contract
│   └── LegacyAI.sol       # AI-enhanced features
├── interfaces/
│   └── ILegacy.sol        # Contract interfaces
├── libraries/
│   └── LegacyTypes.sol    # Custom types and structs
└── verifiers/
    └── Halo2Verifier.sol  # ZK-proof verification
```

## 🔧 Technical Specifications

- **Smart Contract Language**: Solidity ^0.8.0
- **ZK-Proof Framework**: Halo2
- **Test Framework**: Hardhat
- **Networks**: Ethereum, Polygon (planned)

## 📋 Prerequisites

- Node.js >=16.0.0
- Hardhat
- OpenZeppelin Contracts
- Halo2 Libraries

## 🚀 Getting Started

```bash
# Clone the repository
git clone https://github.com/YourUsername/Legacy-contract.git

# Install dependencies
npm install

# Run tests
npx hardhat test

# Deploy locally
npx hardhat node
npx hardhat run scripts/deploy.js --network localhost
```

## 🧪 Testing

```bash
# Run all tests
npm test

# Run specific test suite
npm test test/Legacy.test.js

# Generate coverage report
npm run coverage
```

Current test coverage: Pending

## 🔐 Security

### Audit Status
- [ ] Internal audit completed
- [ ] External audit pending
- [ ] Bug bounty program planned

### Security Measures
- Zero-knowledge proofs for privacy
- Time-locks for asset protection
- Multi-signature requirements
- Emergency shutdown mechanism
- Rate limiting
- Gas optimization

## 📊 Performance

- Gas optimization reports pending
- Performance benchmarks pending
- Network stress tests pending

## 🗺️ Roadmap

### Phase 1 (Q3 2025)
- [* ] Core contract development
- [ ] Basic test suite
- [ ] Initial security audit

### Phase 2 (Q4 2025)
- [ ] Advanced features implementation
- [ ] Comprehensive testing
- [ ] External audit

### Phase 3 (Q1 2026)
- [ ] UI/UX development
- [ ] Mobile app integration
- [ ] Mainnet deployment

## 👥 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Process
1. Fork the repository
2. Create a feature branch
3. Commit changes
4. Submit pull request
5. Pass code review
6. Merge to main

## 📄 License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE). Solidity sources already used `SPDX-License-Identifier: MIT`; this README previously listed CC BY-NC-ND by mistake.

### Relation to NozyWallet

This EVM vault holds an ERC-20 (`LGC`), not Zcash Ironwood notes. Inheritance / yield-while-waiting for **cTAZ** is a **NozyWallet Crosslink lab** (feature-net stake → earn on bond → unbond → withdraw). Do not treat these Solidity contracts as Ironwood custody.

## 📞 Contact & Support

- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Security**: Report vulnerabilities to security@example.com
- **Twitter**: [@Ladalelowo](https://twitter.com/@leoninedao)

## 🙏 Acknowledgments

- OpenZeppelin for security patterns
- Halo2 team for ZK-proof framework


---
⚠️ **Disclaimer**: This project is in active development. Use at your own risk. 
