# 🚀 GigChain - Decentralized Freelance Marketplace

A blockchain-based freelance marketplace that eliminates intermediaries and ensures automatic payments through smart contracts on the Stacks blockchain.

## ✨ Features

- 🎯 **Post Gigs**: Clients can create freelance projects with budgets and deadlines
- 💰 **Smart Bidding**: Freelancers submit competitive bids with proposals
- 🔒 **Escrow Protection**: Automatic escrow holds funds until work completion
- ✅ **Work Verification**: Submit and approve work with dispute resolution
- ⚡ **Instant Payments**: Automatic STX transfers upon work approval
- 📊 **Reputation System**: Track user performance and build trust
- 🛡️ **Dispute Resolution**: Built-in mediation system for conflicts

## 🏗️ Contract Overview

GigChain operates through several key functions:

### 📝 Core Functions

#### For Clients
- `create-gig` - Post new freelance projects
- `select-bid` - Choose winning proposals and lock funds in escrow
- `approve-work` - Approve completed work and release payments
- `cancel-gig` - Cancel open projects
- `raise-dispute` - Initiate dispute resolution

#### For Freelancers
- `place-bid` - Submit proposals for projects
- `submit-work` - Deliver completed work
- `raise-dispute` - Contest client decisions

#### For Platform Admin
- `resolve-dispute` - Mediate conflicts between parties
- `update-platform-fee` - Adjust platform commission (max 10%)

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet with STX tokens

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-username/GigChain
cd GigChain
```

2. Install dependencies:
```bash
npm install
```

3. Run tests:
```bash
clarinet test
```

## 📖 Usage Examples

### Creating a Gig
```clarity
(contract-call? .GigChain create-gig 
    "Build React Website" 
    "Need a responsive website with modern design" 
    u1000000 
    u1640995200)
```

### Placing a Bid
```clarity
(contract-call? .GigChain place-bid 
    u1 
    u800000 
    u7 
    "I can deliver this in 1 week with React and Tailwind")
```

### Selecting a Bid (Client)
```clarity
(contract-call? .GigChain select-bid u1 u1)
```

### Submitting Work (Freelancer)
```clarity
(contract-call? .GigChain submit-work 
    u1 
    "Website completed with all requirements met")
```

### Approving Work (Client)
```clarity
(contract-call? .GigChain approve-work u1)
```

## 🔍 Read-Only Functions

- `get-gig` - View gig details
- `get-bid` - View bid information
- `get-user-profile` - Check user reputation and stats
- `get-work-submission` - View submitted work
- `get-escrow-balance` - Check escrow amounts
- `get-platform-fee` - View current platform fee

## 💡 Smart Contract Logic

### Gig Lifecycle
1. **Open** - Accepting bids from freelancers
2. **In Progress** - Work being completed by selected freelancer
3. **Completed** - Work approved and payment released
4. **Disputed** - Conflict raised, awaiting resolution
5. **Resolved** - Dispute settled by platform admin
6. **Cancelled** - Gig cancelled by client

### Payment Flow
- Client creates gig with budget
- Freelancer places bid
- Client selects bid → STX locked in escrow
- Freelancer submits work
- Client approves → Payment released (minus 2.5% platform fee)

### Reputation System
- Freelancers gain +5 reputation per completed gig
- All users start with 100 reputation points
- Track total gigs, completed work, and earnings

## 🛠️ Development

### Running Tests
```bash
clarinet test
```

### Checking Syntax
```bash
clarinet check
```

### Console Testing
```bash
clarinet console
```

## 🔐 Security Features

- Escrow protection for all transactions
- Multi-party dispute resolution
- Reputation-based trust system
- Time-based gig expiration
- Access control for all functions

## 📊 Platform Economics

- Default platform fee: 2.5% (250 basis points)
- Maximum platform fee: 10% (adjustable by admin)
- Instant settlement upon approval
- No hidden fees or charges

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For support and questions:
- Open an issue on GitHub
- Join our Discord community
- Check the documentation wiki

---

Built with ❤️ on Stacks blockchain
