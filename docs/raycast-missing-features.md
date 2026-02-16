# Raycast Missing Features

This document outlines features that Raycast is missing compared to competitor launchers and tools, as well as commonly requested features from users. This research helps identify opportunities for Zest to differentiate itself in the market.

## Features in Competitors

### 1. Advanced Clipboard History with Snippets

**Competitor:** Alfred, Clipy, Maccy, LaunchBar, Keyboard Maestro

**Description:**
- **Alfred** offers a robust Clipboard History with the ability to paste history items and a powerful Snippets feature for text expansion. Users can create snippets with placeholder variables like {clipboard}, {date}, {time}, and more.
- **Clipy** supports multi-format clipboard history (plain text and images) with snippets functionality for quick pasting of commonly used text.
- **Maccy** provides lightweight clipboard management with pinning items, configurable clipboard check intervals (as fast as 500ms), and the ability to ignore copied items temporarily or permanently.
- **LaunchBar** includes clipboard history tracking and snippet management.
- **Keyboard Maestro** offers advanced clipboard filtering and multiple entry clipboard history, plus text expansion with variables.

**Value:**
- Power users frequently copy and paste multiple items. Advanced clipboard history saves significant time
- Snippets with variable support enable dynamic text expansion (e.g., auto-filling dates, clipboard content)
- Fast clipboard check intervals ensure no copied items are missed

---

### 2. Powerful Workflow Automation

**Competitor:** Alfred (Powerpack), Keyboard Maestro, BetterTouchTool

**Description:**
- **Alfred Powerpack** allows users to create complex workflows without coding using a visual workflow builder. These can connect multiple actions, APIs, and services
- **Keyboard Maestro** provides hundreds of built-in actions for automating applications, websites, text, images. Supports conditions, looping, and scheduled triggers
- **BetterTouchTool** offers window management, gesture controls, and powerful automation triggers

**Value:**
- Enables non-technical users to automate complex repetitive tasks
- Visual workflow builders lower the barrier to automation
- Integration with hundreds of apps without writing code

---

### 3. File Buffer / Batch File Operations

**Competitor:** Alfred

**Description:**
- Alfred's File Buffer allows users to queue multiple files and then perform actions on them as a batch (copy, move, rename, compress)

**Value:**
- Enables batch operations without opening Finder windows
- Faster workflow for managing multiple files

---

### 4. Quick Look Preview

**Competitor:** Alfred, LaunchBar

**Description:**
- Both Alfred and LaunchBar support Quick Look preview directly in the launcher interface, allowing users to preview files, images, documents without opening them

**Value:**
- Quick verification of file contents before opening
- Faster file browsing workflow

---

### 5. Large Type Display

**Competitor:** Alfred

**Description:**
- Alfred's Large Type feature displays text in a large, full-screen format - useful for sharing content during presentations or meetings

**Value:**
- Quick content sharing in face-to-face or remote meetings
- Accessibility feature for users with visual impairments

---

### 6. Built-in System Commands

**Competitor:** Alfred, LaunchBar

**Description:**
- **Alfred** includes extensive system commands: sleep, restart, shutdown, empty trash, screensaver, lock, bluetooth controls, Wi-Fi toggle, volume control, brightness adjustment
- **LaunchBar** provides similar system controls

**Value:**
- Complete system control without leaving the keyboard
- Faster access to common system functions

---

### 7. Contacts Integration

**Competitor:** Alfred, LaunchBar

**Description:**
- Both launchers can search and access contacts directly, allowing users to quickly copy email addresses, phone numbers, or other contact information

**Value:**
- Quick access to contact information without opening Contacts app

---

### 8. 1Password Integration (Deep)

**Competitor:** Alfred, LaunchBar

**Description:**
- Alfred has deep 1Password integration allowing direct access to passwords, credit cards, identities, and secure notes
- Can autofill login credentials in browsers and apps

**Value:**
- Seamless password management across the system
- Enhanced security through secure credential access

---

### 9. Usage Statistics / Analytics

**Competitor:** LaunchBar

**Description:**
- LaunchBar provides detailed usage statistics showing which features and commands are used most, helping users discover untapped capabilities

**Value:**
- Helps users understand their own productivity patterns
- Discovers underutilized features

---

### 10. Multiple Clipboard History Storage Duration Settings

**Competitor:** Maccy, Clipy

**Description:**
- Maccy allows configurable clipboard check intervals and the ability to set how long items are retained
- Clipy provides similar history management

**Value:**
- Control over storage size and privacy
- Customizable retention policies

---

### 11. Shell / Terminal Integration

**Competitor:** Alfred, LaunchBar

**Description:**
- Alfred and LaunchBar both integrate deeply with the shell, allowing users to run terminal commands, scripts, and access system functions

**Value:**
- Power user workflow for developers and system administrators

---

### 12. OCR Capabilities

**Competitor:** Keyboard Maestro

**Description:**
- Keyboard Maestro includes OCR functionality to extract text from images

**Value:**
- Extract text from screenshots, photos, scanned documents
- Automation of text extraction workflows

---

### 13. Calendar / Reminders Deep Integration

**Competitor:** LaunchBar, Raycast (limited)

**Description:**
- **LaunchBar** offers comprehensive calendar and reminders management: create events, view calendars, set reminders
- Raycast has calendar extensions but users request deeper integration

**Value:**
- Quick event creation and management
- Full calendar overview without opening Calendar app

---

### 14. Window Management

**Competitor:** BetterTouchTool, Rectangle, Slate

**Description:**
- **BetterTouchTool** and other window management tools provide extensive window snapping, resizing, and positioning capabilities
- Raycast has basic window management commands but not as comprehensive

**Value:**
- Organize windows across multiple monitors
- Increase productivity with efficient window layouts

---

### 15. Multi-Language Support

**Competitor:** Maccy

**Description:**
- Maccy has multi-language translation support via Weblate

**Value:**
- Accessibility for international users

---

## Commonly Requested Features

Based on user feedback and feature requests:

### 1. Windows Compatibility
- Users repeatedly request Windows versions of Raycast extensions
- Wireguard, Trakt Manager, Plex, Solidtime extensions all have Windows compatibility requests

### 2. Browser Support Beyond Chrome
- Users request support for additional browsers: Zen Browser, Arc, Brave, etc.
- Browser History extension support for more browsers

### 3. Advanced Snippets with Variables
- Users want more powerful text expansion with variables (dates, clipboard content, calculations)
- Dynamic snippets that can transform text

### 4. Default Presets for Extensions
- Users request default settings for extensions (e.g., image output format, quality presets)
- Less configuration needed for common use cases

### 5. Improved Clipboard Features
- Faster clipboard check intervals
- Better image support in clipboard history
- Pinning clipboard items

### 6. Deeper System Integration
- More system-level controls
- Better notification management
- Enhanced window management

### 7. Offline Mode / Local-First Features
- Some users prefer local processing for privacy
- Reduced cloud dependencies

### 8. Custom Themes and UI Customization
- More appearance customization options
- Better dark mode support

### 9. Advanced Workflow Building
- Visual workflow builder for non-coders
- More pre-built automation templates

### 10. Multi-Monitor Support
- Better handling of multiple displays
- Per-monitor configurations

---

## Our Opportunities

Based on the research, here are opportunities for Zest to differentiate:

### 1. Advanced Clipboard Manager with Snippets
- Build a powerful clipboard manager with:
  - Fast history (configurable intervals)
  - Snippets with variable support (dates, clipboard, calculations)
  - Image and multi-format support
  - Pinning and organization
- This is a highly requested feature that users consistently want

### 2. Visual Workflow Builder
- Create a no-code workflow automation tool
- Enable complex automations without programming
- Pre-built templates for common workflows

### 3. Enhanced Window Management
- Comprehensive window snapping and management
- Multi-monitor support
- Customizable window layouts

### 4. Deep System Integration
- Extensive system controls (more than current launchers)
- Notification management
- Menu bar integration
- System-wide hotkeys

### 5. Privacy-First Architecture
- Local processing for sensitive data
- No cloud dependencies for core features
- User-controlled data retention

### 6. Cross-Platform (Future)
- Windows and Linux support
- Sync across platforms
- This is a top request for Raycast

### 7. Advanced Text Expansion
- Snippets with scripting support
- Conditional text expansion
- Form-aware expansions
- OCR-powered expansions

### 8. Developer-Focused Features
- Enhanced terminal integration
- Script management
- Dev tool integrations (Git, Docker, etc.)

### 9. Accessibility-First Design
- VoiceOver support
- Keyboard-only navigation
- Large Type display

### 10. Usage Analytics
- Help users discover their productivity patterns
- Suggest underutilized features
- Track time savings

---

## Key Differentiators to Pursue

The highest-value opportunities for Zest are:

1. **Superior Clipboard Management** - Combine the best of Maccy, Clipy, and Alfred's clipboard features into one powerful tool
2. **Visual Workflow Automation** - Make automation accessible to non-coders with a powerful but easy-to-use builder
3. **Privacy-First Architecture** - Local processing, user-controlled data, no mandatory cloud
4. **Cross-Platform Support** - Windows and Linux versions would address major user demand
5. **Advanced Window Management** - Comprehensive window control beyond basic snapping

---

## Sources

- [Raycast Official Website](https://www.raycast.com/)
- [Alfred Official Website](https://www.alfredapp.com/)
- [LaunchBar Official Website](https://www.obdev.at/products/launchbar/index.html)
- [Maccy GitHub Repository](https://github.com/p0deje/Maccy)
- [Clipy Official Website](https://clipy-app.com/)
- [Keyboard Maestro Official Website](https://www.keyboardmaestro.com/main/)
- [BetterTouchTool (folivora.ai)](https://folivora.ai/)
- [Raycast Extensions GitHub Issues](https://github.com/raycast/extensions/issues)
