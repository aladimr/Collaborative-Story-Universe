# Collaborative Story Universe

A decentralized platform for collaborative storytelling where creators earn from their contributions to shared fictional worlds.

##  Overview
This project implements a smart contract on the Stacks blockchain that enables:
- Community-driven story creation and collaboration
- Democratic voting on story chapters
- Automated earnings distribution to creators and contributors
- Reputation-based incentive systems

##  Features

### Core Functionality
- **Story Universe Creation**: Writers can create shared fictional worlds
- **Chapter Submission**: Submit new chapters for community review
- **Democratic Voting**: Community votes on chapter approvals (24-hour voting periods)
- **Earnings Distribution**: Automated revenue sharing (50% creator, 48% contributors, 2% platform)
- **Reputation System**: Track and reward active contributors
- **User Profiles**: Customizable profiles with statistics tracking

### Technical Features  
- **IPFS Integration**: Decentralized content storage
- **Gas Optimization**: Efficient data structures and operations
- **Security**: Comprehensive error handling and access controls
- **Transparency**: All transactions and votes are on-chain

##  Smart Contract Functions

### Story Management
- `create-story(title, description)` - Create a new story universe
- `get-story(story-id)` - Retrieve story details
- `contribute-to-story(story-id, amount)` - Fund a story and distribute earnings

### Chapter System
- `submit-chapter(story-id, title, content-hash)` - Submit chapter for voting
- `vote-chapter(story-id, chapter-id, vote-for)` - Vote on proposed chapters  
- `finalize-chapter-voting(story-id, chapter-id)` - Complete voting process
- `get-chapter(story-id, chapter-id)` - Get chapter details

### User System
- `update-profile(username, bio)` - Create/update user profile
- `get-user-profile(user)` - Get user profile and statistics
- `get-contributor-stats(story-id, contributor)` - Get contribution statistics

##  Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) - Stacks smart contract development tool
- [Node.js](https://nodejs.org/) - For running tests
- [Git](https://git-scm.com/) - Version control

### Installation
```bash
# Clone the repository
git clone https://github.com/aladimr/Collaborative-Story-Universe.git
cd Collaborative-Story-Universe

# Navigate to contract directory
cd Collaborative-Story-Universe

# Check contract syntax
clarinet check

# Run tests
clarinet test

# Deploy to devnet for testing
clarinet integrate