import './App.css'
import { motion } from 'framer-motion'

// Agent data with colors
const agents = [
  { name: 'Antigravity', color: '#f97316' },
  { name: 'Claude Code', color: '#d97706' },
  { name: 'Cline', color: '#10b981' },
  { name: 'CodeBuddy', color: '#3b82f6' },
  { name: 'Codex', color: '#8b5cf6' },
  { name: 'Command Code', color: '#f97316' },
  { name: 'Continue', color: '#ec4899' },
  { name: 'Crush', color: '#f59e0b' },
  { name: 'Cursor', color: '#6366f1' },
  { name: 'Droid', color: '#10b981' },
  { name: 'Gemini CLI', color: '#3b82f6' },
  { name: 'GitHub Copilot', color: '#22d3ee' },
  { name: 'Goose', color: '#f97316' },
  { name: 'Junie', color: '#ec4899' },
  { name: 'Kilo Code', color: '#8b5cf6' },
  { name: 'Kiro CLI', color: '#3b82f6' },
  { name: 'Kode', color: '#10b981' },
  { name: 'MCPJam', color: '#f59e0b' },
  { name: 'Mux', color: '#ec4899' },
  { name: 'Neovatr', color: '#6366f1' },
  { name: 'OpenCode', color: '#3b82f6' },
  { name: 'Roo Code', color: '#8b5cf6' },
  { name: 'Windsurf', color: '#22d3ee' },
  { name: 'Zed', color: '#f59e0b' },
  { name: 'ZenCoder', color: '#10b981' },
]

const features = [
  {
    icon: '🤖',
    title: '25+ Agents',
    description: 'Support for Cursor, Claude Code, Windsurf, Cline, Antigravity, Goose, and many more AI coding agents.',
    color: '#f97316'
  },
  {
    icon: '📦',
    title: 'Install Skills',
    description: 'Install skills directly from GitHub repositories or local folders with one click.',
    color: '#3b82f6'
  },
  {
    icon: '📚',
    title: 'Registry',
    description: 'Manage multiple skill sources with automatic update detection and notifications.',
    color: '#8b5cf6'
  },
  {
    icon: '📁',
    title: 'Projects',
    description: 'Install skills globally or per-project. Keep your workspace organized.',
    color: '#10b981'
  },
  {
    icon: '🔍',
    title: 'Search',
    description: 'Find and discover skills from skills.sh with installation counts and ratings.',
    color: '#ec4899'
  },
  {
    icon: '🔄',
    title: 'Auto-Updates',
    description: 'Built-in app updater via Sparkle keeps you always up to date.',
    color: '#22d3ee'
  },
]

// Base URL for assets
const baseUrl = import.meta.env.BASE_URL;

const screenshots = [
  { src: `${baseUrl}dashboard.png`, title: 'Dashboard', description: 'Overview of skills, agents, and projects' },
  { src: `${baseUrl}agents.png`, title: 'Agents', description: 'Manage all supported AI coding agents' },
  { src: `${baseUrl}search.png`, title: 'Search', description: 'Discover new skills from the community' },
  { src: `${baseUrl}registry.png`, title: 'Registry', description: 'Manage skill sources and updates' },
]

function App() {
  return (
    <div className="app">
      {/* Navigation */}
      <motion.nav 
        className="nav"
        initial={{ y: -100 }}
        animate={{ y: 0 }}
        transition={{ duration: 0.5 }}
      >
        <div className="nav-container">
          <div className="nav-brand">

            <span className="nav-title">Forks</span>
          </div>
          <div className="nav-links">
            <a href="#features">Features</a>
            <a href="#screenshots">Screenshots</a>
            <a href="#agents">Agents</a>
            <a href="https://github.com/fxding/forks/releases" target="_blank" rel="noopener noreferrer" className="nav-cta">
              Download
            </a>
          </div>
        </div>
      </motion.nav>

      {/* Hero Section */}
      <section className="hero hero-gradient">
        <div className="hero-content">
          <motion.div 
            className="hero-badge"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.2 }}
          >
            <span>✨ Native macOS App</span>
          </motion.div>
          <motion.h1 
            className="hero-title"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 }}
          >
            Manage AI Coding Agent
            <span className="gradient-text"> Skills</span>
          </motion.h1>
          <motion.p 
            className="hero-subtitle"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4 }}
          >
            A powerful native macOS app for installing, managing, and updating skills 
            across 25+ AI coding agents. One app to rule them all.
          </motion.p>
          <motion.div 
            className="hero-buttons"
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.5 }}
          >
            <a href="https://github.com/fxding/forks/releases" className="btn-primary" target="_blank" rel="noopener noreferrer">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 14l-4-4 1.41-1.41L11 13.17l5.59-5.59L18 9l-7 7z"/>
              </svg>
              Download for macOS
            </a>
            <a href="https://github.com/fxding/forks" className="btn-secondary" target="_blank" rel="noopener noreferrer">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
                <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
              </svg>
              View on GitHub
            </a>
          </motion.div>
          <motion.div 
            className="hero-requirements"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.6 }}
          >
            <span>macOS 13.0+</span>
            <span className="separator">•</span>
            <span>Swift 5.9+</span>
            <span className="separator">•</span>
            <span>Node.js Required</span>
          </motion.div>
        </div>
        
        {/* Hero Screenshot */}
        <div className="hero-screenshot">
          <motion.div 
            className="screenshot-wrapper"
            initial={{ opacity: 0, y: 40, scale: 0.95 }}
            animate={{ opacity: 1, y: 0, scale: 1 }}
            transition={{ delay: 0.6, duration: 0.8 }}
          >
            <img src={`${baseUrl}dashboard.png`} alt="Forks Dashboard" className="screenshot-main" />
          </motion.div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="section features-section">
        <div className="section-container">
          <div className="section-header">
            <h2 className="section-title">
              Everything you need to manage
              <span className="gradient-text"> AI Skills</span>
            </h2>
            <p className="section-subtitle">
              Forks provides a unified interface for managing skills across all major AI coding agents.
            </p>
          </div>
          
          <motion.div 
            className="features-grid"
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: "-100px" }}
            variants={{
              hidden: { opacity: 0 },
              visible: {
                opacity: 1,
                transition: { staggerChildren: 0.1 }
              }
            }}
          >
            {features.map((feature, index) => (
              <motion.div 
                key={index} 
                className="feature-card" 
                style={{'--accent-color': feature.color} as React.CSSProperties}
                variants={{
                  hidden: { opacity: 0, y: 20 },
                  visible: { opacity: 1, y: 0 }
                }}
              >
                <div className="feature-icon">{feature.icon}</div>
                <h3 className="feature-title">{feature.title}</h3>
                <p className="feature-description">{feature.description}</p>
              </motion.div>
            ))}
          </motion.div>
        </div>
      </section>

      {/* Screenshots Section */}
      <section id="screenshots" className="section screenshots-section">
        <div className="section-container">
          <div className="section-header">
            <h2 className="section-title">
              Beautiful
              <span className="gradient-text"> Interface</span>
            </h2>
            <p className="section-subtitle">
              A native macOS experience with a clean, intuitive design.
            </p>
          </div>
          
          <div className="screenshots-grid">
            {screenshots.map((screenshot, index) => (
              <motion.div 
                key={index} 
                className="screenshot-card"
                initial={{ opacity: 0, y: 30 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true, margin: "-100px" }}
                transition={{ delay: index * 0.1, duration: 0.5 }}
              >
                <div className="screenshot-image-wrapper">
                  <img src={screenshot.src} alt={screenshot.title} />
                </div>
                <div className="screenshot-info">
                  <h4>{screenshot.title}</h4>
                  <p>{screenshot.description}</p>
                </div>
              </motion.div>
            ))}
          </div>
        </div>
      </section>

      {/* Agents Section */}
      <section id="agents" className="section agents-section">
        <div className="section-container">
          <div className="section-header">
            <h2 className="section-title">
              <span className="gradient-text">25+ </span>
              Supported Agents
            </h2>
            <p className="section-subtitle">
              Works with all major AI coding agents out of the box.
            </p>
          </div>
          
          <motion.div 
            className="agents-cloud"
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true }}
            variants={{
              hidden: { opacity: 0 },
              visible: {
                opacity: 1,
                transition: { staggerChildren: 0.05 }
              }
            }}
          >
            {agents.map((agent, index) => (
              <motion.div 
                key={index} 
                className="agent-badge"
                style={{ 
                  '--badge-color': agent.color,
                } as React.CSSProperties}
                variants={{
                  hidden: { opacity: 0, scale: 0.8 },
                  visible: { opacity: 1, scale: 1 }
                }}
              >
                {agent.name}
              </motion.div>
            ))}
          </motion.div>
        </div>
      </section>

      {/* Install Section */}
      <section id="install" className="section install-section">
        <div className="section-container">
          <motion.div 
            className="install-card gradient-border"
            initial={{ opacity: 0, scale: 0.95 }}
            whileInView={{ opacity: 1, scale: 1 }}
            viewport={{ once: true }}
            transition={{ duration: 0.5 }}
          >
            <div className="install-content">
              <h2 className="install-title">
                Ready to get started?
              </h2>
              <p className="install-description">
                Download Forks and start managing your AI coding skills in minutes.
              </p>
              
              <div className="install-steps">
                <div className="install-step">
                  <span className="step-number">1</span>
                  <div className="step-content">
                    <h4>Download</h4>
                    <p>Get the latest release from GitHub</p>
                  </div>
                </div>
                <div className="install-step">
                  <span className="step-number">2</span>
                  <div className="step-content">
                    <h4>Install</h4>
                    <p>Move to Applications folder</p>
                  </div>
                </div>
                <div className="install-step">
                  <span className="step-number">3</span>
                  <div className="step-content">
                    <h4>Launch</h4>
                    <p>Start managing your skills!</p>
                  </div>
                </div>
              </div>

              <div className="install-code">
                <code>
                  <span className="code-comment"># If blocked by Gatekeeper:</span>
                  <br />
                  xattr -cr /Applications/forks.app
                </code>
              </div>

              <a href="https://github.com/fxding/forks/releases" className="btn-primary btn-large" target="_blank" rel="noopener noreferrer">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M19 9h-4V3H9v6H5l7 7 7-7zM5 18v2h14v-2H5z"/>
                </svg>
                Download Latest Release
              </a>
            </div>
          </motion.div>
        </div>
      </section>

      {/* Footer */}
      <footer className="footer">
        <div className="footer-container">
          <div className="footer-brand">

            <span>Forks</span>
          </div>
          <div className="footer-links">
            <a href="https://github.com/fxding/forks" target="_blank" rel="noopener noreferrer">GitHub</a>
            <a href="https://github.com/fxding/forks/releases" target="_blank" rel="noopener noreferrer">Releases</a>
            <a href="https://github.com/fxding/forks/issues" target="_blank" rel="noopener noreferrer">Issues</a>
          </div>
          <div className="footer-copyright">
            <p>MIT License © 2025</p>
          </div>
        </div>
      </footer>
    </div>
  )
}

export default App
