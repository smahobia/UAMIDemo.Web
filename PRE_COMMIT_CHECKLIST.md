# Pre-Commit Checklist

Before committing your changes, please verify the following:

## 🔒 Security & Secrets
- [ ] No real Azure credentials in any configuration files
- [ ] All placeholder values used: `<your-keyvault-name>`, `<your-tenant-id>`, etc.
- [ ] No hardcoded API keys, connection strings, or passwords
- [ ] No real client IDs in appsettings.json
- [ ] Get-AzureIds.ps1 removed or sanitized if it contains test data
- [ ] Environment variables file (.env) not committed (if exists)

## 🧹 Build Artifacts
- [ ] No `bin/` directories
- [ ] No `obj/` directories  
- [ ] No `.vs/` directories
- [ ] No temporary files (tmpclaude-*, *.tmp, etc.)
- [ ] No `node_modules/` or npm artifacts

## 📝 Configuration Files
- [ ] `appsettings.json` uses only placeholders for Azure settings
- [ ] `appsettings.Development.json` is appropriate for development
- [ ] `appsettings.Production.json` is appropriate for production
- [ ] No user-specific settings committed (like local paths)

## ✅ Code Quality
- [ ] Code builds successfully: `dotnet build` (.NET 10)
- [ ] No compiler warnings or errors
- [ ] Code follows existing style conventions
- [ ] Meaningful commit message provided
- [ ] Uses modern Azure.Identity API (ManagedIdentityId patterns)

## 📚 Documentation
- [ ] README.md is up-to-date
- [ ] .copilot-instructions reflects current architecture
- [ ] Comments added for complex logic
- [ ] API endpoints documented if changed

## 🔧 Git Configuration
- [ ] `.gitignore` is in place and excludes sensitive files
- [ ] Verified with: `git status` (should not show secrets)
- [ ] Verified with: `git diff --cached` (review staged changes)

## 🚀 Pre-Commit Commands
```bash
# Verify no build artifacts exist
dotnet clean

# Build to ensure no errors
dotnet build

# Check what will be committed
git status

# Review staged changes
git diff --cached

# Final verification - check for common secret patterns
git diff --cached | grep -i "password\|secret\|key\|token\|credential"
```

## ⚠️ Common Mistakes to Avoid
- ❌ Don't commit real KeyVault URLs with actual names
- ❌ Don't commit real TenantIds or ClientIds
- ❌ Don't commit `.env` or local settings files
- ❌ Don't commit build artifacts (bin/, obj/, .vs/)
- ❌ Don't commit API keys or connection strings
- ❌ Don't commit local-only configuration

## ✨ Ready to Commit?
If you've checked all items above, you're ready to:
```bash
git add .
git commit -m "Your descriptive commit message"
git push origin <branch-name>
```

---
**Remember**: A single committed secret can compromise your Azure resources!
