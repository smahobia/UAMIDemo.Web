# UAMIDemo.Web .NET 10.0 Upgrade Tasks

## Overview

This document tracks the execution of the UAMIDemo.Web project upgrade from .NET 8.0 to .NET 10.0 (Long Term Support). The single project will be upgraded in one atomic operation following the All-At-Once strategy.

**Progress**: 3/3 tasks complete (100%) ![0%](https://progress-bar.xyz/100)

---

## Tasks

### [✓] TASK-001: Verify prerequisites *(Completed: 2026-02-28 14:03)*
**References**: Plan §Phase 0 Prerequisites

- [✓] (1) Verify .NET 10 SDK installed per Plan §Prerequisites
- [✓] (2) SDK version meets minimum requirements (**Verify**)

---

### [✓] TASK-002: Atomic framework and dependency upgrade with compilation fixes *(Completed: 2026-02-28 14:05)*
**References**: Plan §Phase 1, Plan §Project-by-Project Plans §UAMIDemo.Web.csproj, Plan §Package Update Reference, Plan §Breaking Changes Catalog

- [✓] (1) Research Azure.Identity 1.14.0 deprecation per Plan §Package Update Reference §Azure.Identity (check release notes, identify target version or replacement, review breaking changes)
- [✓] (2) Deprecation research complete and target version determined (**Verify**)
- [✓] (3) Update UAMIDemo.Web.csproj TargetFramework from net8.0 to net10.0
- [✓] (4) TargetFramework updated to net10.0 (**Verify**)
- [✓] (5) Update package references per Plan §Package Update Reference (Microsoft.AspNetCore.Mvc.Razor.RuntimeCompilation 8.0.2 → 10.0.3, Azure.Identity 1.14.0 → determined version)
- [✓] (6) All package references updated (**Verify**)
- [✓] (7) Restore all dependencies with `dotnet restore`
- [✓] (8) All dependencies restored successfully (**Verify**)
- [✓] (9) Build solution and fix all compilation errors per Plan §Breaking Changes Catalog (focus: Configure<T> binary incompatible API in Program.cs, Azure.Identity API changes if applicable, System.Uri behavioral changes, UseExceptionHandler behavioral changes)
- [✓] (10) Solution builds with 0 errors (**Verify**)

---

### [✓] TASK-003: Final commit *(Completed: 2026-02-28 14:06)*
**References**: Plan §Source Control Strategy

- [✓] (1) Commit all changes with message: "Upgrade UAMIDemo.Web to .NET 10.0 - Update target framework from net8.0 to net10.0 - Update Microsoft.AspNetCore.Mvc.Razor.RuntimeCompilation to 10.0.3 - Address Azure.Identity deprecation - Fix Configure<T> binary incompatible API - Address behavioral changes (System.Uri, UseExceptionHandler) - Verify application builds with 0 errors"

---














