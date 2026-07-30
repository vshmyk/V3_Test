using Microsoft.Data.SqlClient;
using System.Text.Json;
using System.Text.Json.Serialization;

var app = new ParspecMigratorApp();
return await app.RunAsync(args);

internal sealed class ParspecMigratorApp
{
    private static readonly HashSet<string> CanadianRegionCodes = new(StringComparer.OrdinalIgnoreCase)
    {
        "AB", "BC", "MB", "NB", "NL", "NS", "NT", "NU", "ON", "PE", "QC", "SK", "YT"
    };

    private static readonly HashSet<string> UnitedStatesRegionCodes = new(StringComparer.OrdinalIgnoreCase)
    {
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS",
        "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY",
        "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV",
        "WI", "WY", "DC"
    };

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNameCaseInsensitive = true
    };

    private static readonly JsonSerializerOptions ApiJsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public async Task<int> RunAsync(string[] args)
    {
        var command = args.FirstOrDefault()?.Trim().ToLowerInvariant() ?? "users-scan";
        var config = ParspecMigratorConfig.Load();

        return command switch
        {
            "users-scan" => await RunUsersScanAsync(config),
            "companies-scan" => await RunCompaniesScanAsync(config),
            "projects-scan" => await RunProjectsScanAsync(config),
            "projects-create" => await RunProjectsCreateAsync(config, args.Skip(1).ToArray()),
            "projects-create-all" => await RunProjectsCreateAllAsync(config, args.Skip(1).ToArray()),
            "opportunities-scan" => await RunOpportunitiesScanAsync(config),
            "boms-scan" => await RunBomsScanAsync(config),
            "bom-lines-scan" => await RunBomLinesScanAsync(config),
            "boms-create" => await RunBomsCreateAsync(config, args.Skip(1).ToArray()),
            "boms-create-all" => await RunBomsCreateAllAsync(config, args.Skip(1).ToArray()),
            "opportunities-create" => await RunOpportunitiesCreateAsync(config, args.Skip(1).ToArray()),
            "opportunities-create-all" => await RunOpportunitiesCreateAllAsync(config, args.Skip(1).ToArray()),
            "companies-create" => await RunCompaniesCreateAsync(config, args.Skip(1).ToArray()),
            "companies-create-all" => await RunCompaniesCreateAllAsync(config),
            "manufacturers-scan" => await RunManufacturersScanAsync(config),
            "manufacturers-create" => await RunManufacturersCreateAsync(config, args.Skip(1).ToArray()),
            "manufacturers-create-all" => await RunManufacturersCreateAllAsync(config),
            "contacts-scan" => await RunContactsScanAsync(config),
            "contacts-create" => await RunContactsCreateAsync(config, args.Skip(1).ToArray()),
            "contacts-create-all" => await RunContactsCreateAllAsync(config),
            "locations-scan" => await RunLocationsScanAsync(config),
            "users-probe-api" => await RunUsersProbeApiAsync(config),
            "users-match-parspec" => await RunUsersMatchParspecAsync(config),
            "users-patch" => await RunUsersPatchAsync(config, args.Skip(1).ToArray()),
            _ => ShowUsage()
        };
    }

    private static int ShowUsage()
    {
        Console.WriteLine("Parspec Migrator");
        Console.WriteLine();
        Console.WriteLine("Commands:");
        Console.WriteLine("  users-scan       Build the first-pass active-user migration report.");
        Console.WriteLine("  companies-scan   Build the first-pass active-company migration report.");
        Console.WriteLine("  projects-scan    Build the first-pass active-project migration report.");
        Console.WriteLine("  projects-create  Create one Parspec project from PARSPEC_MACSII.src.Project.");
        Console.WriteLine("                   Usage: projects-create <projectErpId>");
        Console.WriteLine("  projects-create-all  Create project candidates in Parspec.");
        Console.WriteLine("                   Usage: projects-create-all [take] [skip]");
        Console.WriteLine("  opportunities-scan  Build the first-pass quote-header/opportunity migration report.");
        Console.WriteLine("  boms-scan        Build the first-pass BOM-header migration report.");
        Console.WriteLine("  bom-lines-scan   Build the first-pass BOM-line migration report.");
        Console.WriteLine("  boms-create      Create one Parspec BOM from PARSPEC_MACSII.src.QuoteItem.");
        Console.WriteLine("                   Usage: boms-create <projectErpId> <quoteId>");
        Console.WriteLine("  boms-create-all  Create BOM candidates in Parspec.");
        Console.WriteLine("                   Usage: boms-create-all [take] [skip]");
        Console.WriteLine("  opportunities-create Create one Parspec opportunity from PARSPEC_MACSII.src.Bid.");
        Console.WriteLine("                   Usage: opportunities-create <projectErpId> <quoteId>");
        Console.WriteLine("  opportunities-create-all  Create opportunity candidates in Parspec.");
        Console.WriteLine("                   Usage: opportunities-create-all [take] [skip]");
        Console.WriteLine("  companies-create Create one Parspec company from PARSPEC_MACSII.src.Account.");
        Console.WriteLine("                   Usage: companies-create <erpCompanyId>");
        Console.WriteLine("  companies-create-all  Create all active customer companies in Parspec.");
        Console.WriteLine("  manufacturers-scan  Build the first-pass active-manufacturer migration report.");
        Console.WriteLine("  manufacturers-create Create one Parspec manufacturer from PARSPEC_MACSII.src.Account.");
        Console.WriteLine("                   Usage: manufacturers-create <erpManufacturerId>");
        Console.WriteLine("  manufacturers-create-all  Create all active manufacturers in Parspec.");
        Console.WriteLine("  contacts-scan    Build the first-pass contact migration report.");
        Console.WriteLine("  contacts-create  Create one Parspec contact from PARSPEC_MACSII.src.Contact.");
        Console.WriteLine("                   Usage: contacts-create <sourceContactId>");
        Console.WriteLine("  contacts-create-all   Create all Parspec contacts from PARSPEC_MACSII.src.Contact.");
        Console.WriteLine("  locations-scan   Build the source-side location/workgroup inventory.");
        Console.WriteLine("  users-probe-api  Probe Parspec /v1/users with the configured API key.");
        Console.WriteLine("  users-match-parspec  Compare active Oasis/AO users to current Parspec users.");
        Console.WriteLine("  users-patch      PATCH an existing Parspec user from a matched Oasis/AO user.");
        Console.WriteLine("                   Usage: users-patch <parspecUserId> <oasisUserId>");
        return 1;
    }

    private static async Task<int> RunUsersScanAsync(ParspecMigratorConfig config)
    {
        Directory.CreateDirectory(config.OutputDirectory);

        var locationMap = config.LocationMappings
            .ToDictionary(
                pair => pair.Key,
                pair => pair.Value,
                StringComparer.OrdinalIgnoreCase);

        var users = await LoadUserCandidatesAsync(config.BusinessConnectionString, locationMap);
        var report = BuildUserReport(users);
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"users-scan.{timestamp}.json");

        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Users scan complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Active Oasis users: {report.Summary.ActiveOasisUsers}");
        Console.WriteLine($"Matched to AO users: {report.Summary.MatchedAoUsers}");
        Console.WriteLine($"Missing AO match: {report.Summary.MissingAoUsers}");
        Console.WriteLine($"AO-only active users: {report.Summary.AoOnlyActiveUsers}");
        Console.WriteLine($"Users with tentative Parspec PATCH candidate: {report.Summary.UsersReadyForPatch}");
        Console.WriteLine($"Users missing Parspec write fields: {report.Summary.UsersWithUnresolvedPatchFields}");

        return 0;
    }

    private static async Task<int> RunCompaniesScanAsync(ParspecMigratorConfig config)
    {
        Directory.CreateDirectory(config.OutputDirectory);

        var report = await BuildCompanyReportAsync(config.BusinessConnectionString);
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"companies-scan.{timestamp}.json");

        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Companies scan complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Active customer companies: {report.Summary.TotalCompanies}");
        Console.WriteLine($"Resolvable base-company fields: {report.Summary.ResolvedBaseFields}/{report.Summary.TotalBaseFields}");
        Console.WriteLine($"Unresolved base-company fields: {report.Summary.UnresolvedBaseFields}");
        Console.WriteLine($"Companies with CRM id: {report.Summary.CompaniesWithCrmId}");
        Console.WriteLine($"Companies with email: {report.Summary.CompaniesWithEmail}");
        Console.WriteLine($"Companies with bill-to address: {report.Summary.CompaniesWithBillAddress}");
        Console.WriteLine($"Companies with notes content: {report.Summary.CompaniesWithNotes}");
        Console.WriteLine($"Companies with sold-to address: {report.Summary.CompaniesWithSoldAddress}");
        Console.WriteLine($"Companies with ship-to address: {report.Summary.CompaniesWithShipAddress}");

        return 0;
    }

    private static async Task<int> RunProjectsScanAsync(ParspecMigratorConfig config)
    {
        Directory.CreateDirectory(config.OutputDirectory);

        var report = await BuildProjectReportAsync(config.BusinessConnectionString, config.LocationMappings);
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"projects-scan.{timestamp}.json");

        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Projects scan complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Active project candidates: {report.Summary.TotalProjects}");
        Console.WriteLine($"Resolvable base-project fields: {report.Summary.ResolvedBaseFields}/{report.Summary.TotalBaseFields}");
        Console.WriteLine($"Unresolved base-project fields: {report.Summary.UnresolvedBaseFields}");
        Console.WriteLine($"Projects with ERP id: {report.Summary.ProjectsWithErpId}");
        Console.WriteLine($"Projects with CRM id: {report.Summary.ProjectsWithCrmId}");
        Console.WriteLine($"Projects with location mapping: {report.Summary.ProjectsWithLocationMapping}");
        Console.WriteLine($"Projects with owner: {report.Summary.ProjectsWithOwner}");
        Console.WriteLine($"Projects with quote distributor: {report.Summary.ProjectsWithQuoteDistributor}");
        Console.WriteLine($"Projects with customer contact: {report.Summary.ProjectsWithCustomerContact}");
        Console.WriteLine($"Projects with market vertical: {report.Summary.ProjectsWithMarketVertical}");

        return 0;
    }

    private static async Task<int> RunProjectsCreateAsync(ParspecMigratorConfig config, string[] args)
    {
        if (args.Length < 1)
        {
            Console.WriteLine("Usage: projects-create <projectErpId>");
            return 1;
        }

        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        var projectErpId = args[0].Trim();
        var projects = await LoadProjectCandidatesAsync(config.BusinessConnectionString, config.LocationMappings);
        var candidate = projects.FirstOrDefault(project =>
            string.Equals(project.ErpId, projectErpId, StringComparison.OrdinalIgnoreCase));

        if (candidate is null)
        {
            Console.WriteLine($"No project candidate found for {projectErpId}.");
            return 1;
        }

        var migrationContext = await BuildProjectMigrationContextAsync(config);
        var result = await CreateOrUpdateProjectAsync(config, candidate, migrationContext);

        Console.WriteLine($"Project result: {result.Status}");
        Console.WriteLine($"Parspec id: {result.ParspecProjectId?.ToString() ?? "(none)"}");
        if (!string.IsNullOrWhiteSpace(result.Message))
        {
            Console.WriteLine(result.Message);
        }

        return result.Status is "created" or "updated-existing" ? 0 : 1;
    }

    private static async Task<int> RunProjectsCreateAllAsync(ParspecMigratorConfig config, string[] args)
    {
        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        Directory.CreateDirectory(config.OutputDirectory);

        var take = ParseOptionalPositiveInt(args, 0);
        var skip = ParseOptionalNonNegativeInt(args, 1) ?? 0;

        if (args.Length > 0 && take is null)
        {
            Console.WriteLine("Usage: projects-create-all [take] [skip]");
            Console.WriteLine("Example: projects-create-all 100 0");
            return 1;
        }

        if (args.Length > 1 && ParseOptionalNonNegativeInt(args, 1) is null)
        {
            Console.WriteLine("Usage: projects-create-all [take] [skip]");
            Console.WriteLine("Example: projects-create-all 100 0");
            return 1;
        }

        var allProjects = await LoadProjectCandidatesAsync(config.BusinessConnectionString, config.LocationMappings);
        var projects = (take.HasValue
                ? allProjects.Skip(skip).Take(take.Value)
                : allProjects.Skip(skip))
            .ToList();
        var migrationContext = await BuildProjectMigrationContextAsync(config);
        var results = new List<ProjectMigrationExecutionResult>(projects.Count);

        Console.WriteLine($"Starting bulk project migration for {projects.Count} project candidates (skip={skip}, take={(take?.ToString() ?? "all")}).");

        for (var index = 0; index < projects.Count; index++)
        {
            var candidate = projects[index];
            var result = await CreateOrUpdateProjectAsync(config, candidate, migrationContext);
            results.Add(result);

            Console.WriteLine($"[{index + 1}/{projects.Count}] {candidate.ErpId} | {candidate.Name} | {result.Status} | Parspec {result.ParspecProjectId?.ToString() ?? "-"}");
        }

        var report = new ProjectBulkMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            Skip = skip,
            Take = take,
            TotalCandidates = projects.Count,
            CreatedCount = results.Count(result => result.Status == "created"),
            UpdatedExistingCount = results.Count(result => result.Status == "updated-existing"),
            FailedCount = results.Count(result => result.Status == "failed"),
            V1EnrichedCount = results.Count(result => result.V1EnrichmentStatus == "applied"),
            V1EnrichmentFailedCount = results.Count(result => result.V1EnrichmentStatus == "failed"),
            Results = results
        };

        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"projects-create-all.skip-{skip}.take-{(take?.ToString() ?? "all")}.{timestamp}.json");
        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Bulk project migration complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Created: {report.CreatedCount}");
        Console.WriteLine($"Updated existing: {report.UpdatedExistingCount}");
        Console.WriteLine($"Failed: {report.FailedCount}");
        Console.WriteLine($"V1 enrichment applied: {report.V1EnrichedCount}");
        Console.WriteLine($"V1 enrichment failed: {report.V1EnrichmentFailedCount}");

        return report.FailedCount == 0 ? 0 : 1;
    }

    private static async Task<int> RunOpportunitiesScanAsync(ParspecMigratorConfig config)
    {
        Directory.CreateDirectory(config.OutputDirectory);

        var report = await BuildOpportunityReportAsync(config.BusinessConnectionString);
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"opportunities-scan.{timestamp}.json");

        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Opportunity scan complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Total opportunity candidates: {report.Summary.TotalOpportunities}");
        Console.WriteLine($"Resolvable base-opportunity fields: {report.Summary.ResolvedBaseFields}/{report.Summary.TotalBaseFields}");
        Console.WriteLine($"Unresolved base-opportunity fields: {report.Summary.UnresolvedBaseFields}");
        Console.WriteLine($"Candidates with project ERP id: {report.Summary.OpportunitiesWithProjectErpId}");
        Console.WriteLine($"Candidates with quote CRM id: {report.Summary.OpportunitiesWithCrmId}");
        Console.WriteLine($"Candidates with quote due date: {report.Summary.OpportunitiesWithQuoteDueDate}");
        Console.WriteLine($"Candidates with submittal due date: {report.Summary.OpportunitiesWithSubmittalDueDate}");
        Console.WriteLine($"Candidates with quoter: {report.Summary.OpportunitiesWithQuoter}");

        return 0;
    }

    private static async Task<int> RunBomsScanAsync(ParspecMigratorConfig config)
    {
        Directory.CreateDirectory(config.OutputDirectory);

        var report = await BuildBomReportAsync(config.BusinessConnectionString);
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"boms-scan.{timestamp}.json");

        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("BOM scan complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Total BOM candidates: {report.Summary.TotalBoms}");
        Console.WriteLine($"Resolvable base-BOM fields: {report.Summary.ResolvedBaseFields}/{report.Summary.TotalBaseFields}");
        Console.WriteLine($"Unresolved base-BOM fields: {report.Summary.UnresolvedBaseFields}");
        Console.WriteLine($"Candidates with quote CRM id: {report.Summary.BomsWithCrmId}");
        Console.WriteLine($"Candidates with name: {report.Summary.BomsWithName}");
        Console.WriteLine($"Candidates with sales agent source: {report.Summary.BomsWithSalesAgent}");
        Console.WriteLine($"Candidates with primary contact source: {report.Summary.BomsWithPrimaryContact}");
        Console.WriteLine($"Candidates with secondary contact source: {report.Summary.BomsWithSecondaryContact}");

        return 0;
    }

    private static async Task<int> RunBomLinesScanAsync(ParspecMigratorConfig config)
    {
        Directory.CreateDirectory(config.OutputDirectory);

        var report = await BuildBomLineReportAsync(config.BusinessConnectionString);
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"bom-lines-scan.{timestamp}.json");

        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("BOM line scan complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Total BOM line candidates: {report.Summary.TotalBomLines}");
        Console.WriteLine($"Resolvable base-BOM-line fields: {report.Summary.ResolvedBaseFields}/{report.Summary.TotalBaseFields}");
        Console.WriteLine($"Unresolved base-BOM-line fields: {report.Summary.UnresolvedBaseFields}");
        Console.WriteLine($"Lines with manufacturer: {report.Summary.LinesWithManufacturerErpId}");
        Console.WriteLine($"Lines with model number: {report.Summary.LinesWithModelNumber}");
        Console.WriteLine($"Lines with quantity: {report.Summary.LinesWithQuantity}");
        Console.WriteLine($"Lines with extended sell: {report.Summary.LinesWithExtendedSellAmount}");

        return 0;
    }

    private static async Task<int> RunBomsCreateAsync(ParspecMigratorConfig config, string[] args)
    {
        if (args.Length < 2)
        {
            Console.WriteLine("Usage: boms-create <projectErpId> <quoteId>");
            return 1;
        }

        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        var projectErpId = args[0].Trim();
        var quoteId = args[1].Trim();
        var candidates = await LoadBomCandidatesAsync(config.BusinessConnectionString);
        var candidate = candidates.FirstOrDefault(bom =>
            string.Equals(bom.ProjectErpId, projectErpId, StringComparison.OrdinalIgnoreCase)
            && string.Equals(bom.QuoteId, quoteId, StringComparison.OrdinalIgnoreCase));

        if (candidate is null)
        {
            Console.WriteLine($"No BOM candidate found for project {projectErpId} and quote {quoteId}.");
            return 1;
        }

        var locationMap = config.LocationMappings
            .Where(pair => pair.Value > 0)
            .ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.OrdinalIgnoreCase);
        var context = await BuildBomMigrationContextAsync(config, locationMap);
        var result = await CreateOrUpdateBomAsync(config, candidate, context);

        Console.WriteLine($"BOM result: {result.Status}");
        Console.WriteLine($"Parspec id: {result.ParspecBomId?.ToString() ?? "(none)"}");
        if (!string.IsNullOrWhiteSpace(result.Message))
        {
            Console.WriteLine(result.Message);
        }

        return result.Status is "created" or "updated-existing" ? 0 : 1;
    }

    private static async Task<int> RunBomsCreateAllAsync(ParspecMigratorConfig config, string[] args)
    {
        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        Directory.CreateDirectory(config.OutputDirectory);

        var take = ParseOptionalPositiveInt(args, 0);
        var skip = ParseOptionalNonNegativeInt(args, 1) ?? 0;

        if (args.Length > 0 && take is null)
        {
            Console.WriteLine("Usage: boms-create-all [take] [skip]");
            Console.WriteLine("Example: boms-create-all 100 0");
            return 1;
        }

        if (args.Length > 1 && ParseOptionalNonNegativeInt(args, 1) is null)
        {
            Console.WriteLine("Usage: boms-create-all [take] [skip]");
            Console.WriteLine("Example: boms-create-all 100 0");
            return 1;
        }

        var allCandidates = await LoadBomCandidatesAsync(config.BusinessConnectionString);
        var candidates = (take.HasValue
                ? allCandidates.Skip(skip).Take(take.Value)
                : allCandidates.Skip(skip))
            .ToList();

        var locationMap = config.LocationMappings
            .Where(pair => pair.Value > 0)
            .ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.OrdinalIgnoreCase);
        var context = await BuildBomMigrationContextAsync(config, locationMap);
        var results = new List<BomMigrationExecutionResult>(candidates.Count);

        Console.WriteLine($"Starting bulk BOM migration for {candidates.Count} BOM-header candidates (skip={skip}, take={(take?.ToString() ?? "all")}).");

        for (var index = 0; index < candidates.Count; index++)
        {
            var candidate = candidates[index];
            var result = await CreateOrUpdateBomAsync(config, candidate, context);
            results.Add(result);

            Console.WriteLine($"[{index + 1}/{candidates.Count}] {candidate.ProjectErpId} | Quote {candidate.QuoteId} | {candidate.Name} | {result.Status} | Parspec {result.ParspecBomId?.ToString() ?? "-"}");
        }

        var report = new BomBulkMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            Skip = skip,
            Take = take,
            TotalCandidates = candidates.Count,
            CreatedCount = results.Count(result => result.Status == "created"),
            UpdatedExistingCount = results.Count(result => result.Status == "updated-existing"),
            FailedCount = results.Count(result => result.Status == "failed"),
            Results = results
        };

        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"boms-create-all.skip-{skip}.take-{(take?.ToString() ?? "all")}.{timestamp}.json");
        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Bulk BOM migration complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Created: {report.CreatedCount}");
        Console.WriteLine($"Updated existing: {report.UpdatedExistingCount}");
        Console.WriteLine($"Failed: {report.FailedCount}");

        return report.FailedCount == 0 ? 0 : 1;
    }

    private static async Task<int> RunOpportunitiesCreateAsync(ParspecMigratorConfig config, string[] args)
    {
        if (args.Length < 2)
        {
            Console.WriteLine("Usage: opportunities-create <projectErpId> <quoteId>");
            return 1;
        }

        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        var projectErpId = args[0].Trim();
        var quoteId = args[1].Trim();
        var candidates = await LoadOpportunityCandidatesAsync(config.BusinessConnectionString);
        var candidate = candidates.FirstOrDefault(opportunity =>
            string.Equals(opportunity.ProjectErpId, projectErpId, StringComparison.OrdinalIgnoreCase)
            && string.Equals(opportunity.QuoteId, quoteId, StringComparison.OrdinalIgnoreCase));

        if (candidate is null)
        {
            Console.WriteLine($"No opportunity candidate found for project {projectErpId} and quote {quoteId}.");
            return 1;
        }

        var locationMap = config.LocationMappings
            .Where(pair => pair.Value > 0)
            .ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.OrdinalIgnoreCase);
        var context = await BuildOpportunityMigrationContextAsync(config, locationMap);
        var result = await CreateOrUpdateOpportunityAsync(config, candidate, context);

        Console.WriteLine($"Opportunity result: {result.Status}");
        Console.WriteLine($"Parspec id: {result.ParspecOpportunityId?.ToString() ?? "(none)"}");
        if (!string.IsNullOrWhiteSpace(result.Message))
        {
            Console.WriteLine(result.Message);
        }

        return result.Status is "created" or "updated-existing" ? 0 : 1;
    }

    private static async Task<int> RunOpportunitiesCreateAllAsync(ParspecMigratorConfig config, string[] args)
    {
        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        Directory.CreateDirectory(config.OutputDirectory);

        var take = ParseOptionalPositiveInt(args, 0);
        var skip = ParseOptionalNonNegativeInt(args, 1) ?? 0;

        if (args.Length > 0 && take is null)
        {
            Console.WriteLine("Usage: opportunities-create-all [take] [skip]");
            Console.WriteLine("Example: opportunities-create-all 100 0");
            return 1;
        }

        if (args.Length > 1 && ParseOptionalNonNegativeInt(args, 1) is null)
        {
            Console.WriteLine("Usage: opportunities-create-all [take] [skip]");
            Console.WriteLine("Example: opportunities-create-all 100 0");
            return 1;
        }

        var allCandidates = await LoadOpportunityCandidatesAsync(config.BusinessConnectionString);
        var candidates = (take.HasValue
                ? allCandidates.Skip(skip).Take(take.Value)
                : allCandidates.Skip(skip))
            .ToList();

        var locationMap = config.LocationMappings
            .Where(pair => pair.Value > 0)
            .ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.OrdinalIgnoreCase);
        var context = await BuildOpportunityMigrationContextAsync(config, locationMap);
        var results = new List<OpportunityMigrationExecutionResult>(candidates.Count);

        Console.WriteLine($"Starting bulk opportunity migration for {candidates.Count} quote-header candidates (skip={skip}, take={(take?.ToString() ?? "all")}).");

        for (var index = 0; index < candidates.Count; index++)
        {
            var candidate = candidates[index];
            var result = await CreateOrUpdateOpportunityAsync(config, candidate, context);
            results.Add(result);

            Console.WriteLine($"[{index + 1}/{candidates.Count}] {candidate.ProjectErpId} | Quote {candidate.QuoteId} | {candidate.Title} | {result.Status} | Parspec {result.ParspecOpportunityId?.ToString() ?? "-"}");
        }

        var report = new OpportunityBulkMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            Skip = skip,
            Take = take,
            TotalCandidates = candidates.Count,
            CreatedCount = results.Count(result => result.Status == "created"),
            UpdatedExistingCount = results.Count(result => result.Status == "updated-existing"),
            FailedCount = results.Count(result => result.Status == "failed"),
            Results = results
        };

        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"opportunities-create-all.skip-{skip}.take-{(take?.ToString() ?? "all")}.{timestamp}.json");
        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Bulk opportunity migration complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Created: {report.CreatedCount}");
        Console.WriteLine($"Updated existing: {report.UpdatedExistingCount}");
        Console.WriteLine($"Failed: {report.FailedCount}");

        return report.FailedCount == 0 ? 0 : 1;
    }

    private static int? ParseOptionalPositiveInt(string[] args, int index)
    {
        if (index >= args.Length)
        {
            return null;
        }

        if (!int.TryParse(args[index], out var value) || value <= 0)
        {
            return null;
        }

        return value;
    }

    private static int? ParseOptionalNonNegativeInt(string[] args, int index)
    {
        if (index >= args.Length)
        {
            return null;
        }

        if (!int.TryParse(args[index], out var value) || value < 0)
        {
            return null;
        }

        return value;
    }

    private static async Task<int> RunCompaniesCreateAsync(ParspecMigratorConfig config, string[] args)
    {
        if (args.Length < 1)
        {
            Console.WriteLine("Usage: companies-create <erpCompanyId>");
            return 1;
        }

        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        var erpCompanyId = args[0].Trim();
        var companies = await LoadCompanyCandidatesAsync(config.BusinessConnectionString);
        var candidate = companies.FirstOrDefault(company =>
            string.Equals(company.ErpId, erpCompanyId, StringComparison.OrdinalIgnoreCase));

        if (candidate is null)
        {
            Console.WriteLine($"No active customer company candidate found for {erpCompanyId}.");
            return 1;
        }

        var migrationContext = await BuildCompanyMigrationContextAsync(config);
        var result = await CreateOrUpdateCompanyAsync(config, candidate, migrationContext);

        Console.WriteLine($"Company result: {result.Status}");
        Console.WriteLine($"Parspec id: {result.ParspecCompanyId?.ToString() ?? "(none)"}");
        if (!string.IsNullOrWhiteSpace(result.Message))
        {
            Console.WriteLine(result.Message);
        }

        return result.Status is "created" or "updated-existing" ? 0 : 1;
    }

    private static async Task<int> RunCompaniesCreateAllAsync(ParspecMigratorConfig config)
    {
        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        Directory.CreateDirectory(config.OutputDirectory);

        var companies = await LoadCompanyCandidatesAsync(config.BusinessConnectionString);
        var migrationContext = await BuildCompanyMigrationContextAsync(config);
        var results = new List<CompanyMigrationExecutionResult>(companies.Count);

        Console.WriteLine($"Starting bulk company migration for {companies.Count} active customer companies.");

        for (var index = 0; index < companies.Count; index++)
        {
            var candidate = companies[index];
            var result = await CreateOrUpdateCompanyAsync(config, candidate, migrationContext);
            results.Add(result);

            Console.WriteLine($"[{index + 1}/{companies.Count}] {candidate.ErpId} | {candidate.Name} | {result.Status} | Parspec {result.ParspecCompanyId?.ToString() ?? "-"}");
        }

        var report = new CompanyBulkMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            TotalCandidates = companies.Count,
            CreatedCount = results.Count(result => result.Status == "created"),
            UpdatedExistingCount = results.Count(result => result.Status == "updated-existing"),
            FailedCount = results.Count(result => result.Status == "failed"),
            Results = results
        };

        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"companies-create-all.{timestamp}.json");
        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Bulk company migration complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Created: {report.CreatedCount}");
        Console.WriteLine($"Updated existing: {report.UpdatedExistingCount}");
        Console.WriteLine($"Failed: {report.FailedCount}");

        return report.FailedCount == 0 ? 0 : 1;
    }

    private static async Task<int> RunManufacturersScanAsync(ParspecMigratorConfig config)
    {
        Directory.CreateDirectory(config.OutputDirectory);

        var report = await BuildManufacturerReportAsync(config.BusinessConnectionString);
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"manufacturers-scan.{timestamp}.json");

        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Manufacturers scan complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Active manufacturers: {report.Summary.TotalManufacturers}");
        Console.WriteLine($"Resolvable base-manufacturer fields: {report.Summary.ResolvedBaseFields}/{report.Summary.TotalBaseFields}");
        Console.WriteLine($"Unresolved base-manufacturer fields: {report.Summary.UnresolvedBaseFields}");
        Console.WriteLine($"Manufacturers with AO account id: {report.Summary.ManufacturersWithAoAccountId}");
        Console.WriteLine($"Manufacturers with phone: {report.Summary.ManufacturersWithPhone}");
        Console.WriteLine($"Manufacturers with website: {report.Summary.ManufacturersWithWebsite}");
        Console.WriteLine($"Manufacturers with fax: {report.Summary.ManufacturersWithFax}");
        Console.WriteLine($"Manufacturers with mailing address: {report.Summary.ManufacturersWithMailAddress}");

        return 0;
    }

    private static async Task<int> RunManufacturersCreateAsync(ParspecMigratorConfig config, string[] args)
    {
        if (args.Length < 1)
        {
            Console.WriteLine("Usage: manufacturers-create <erpManufacturerId>");
            return 1;
        }

        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        var erpManufacturerId = args[0].Trim();
        var manufacturers = await LoadManufacturerCandidatesAsync(config.BusinessConnectionString);
        var candidate = manufacturers.FirstOrDefault(manufacturer =>
            string.Equals(manufacturer.ErpId, erpManufacturerId, StringComparison.OrdinalIgnoreCase));

        if (candidate is null)
        {
            Console.WriteLine($"No active manufacturer candidate found for {erpManufacturerId}.");
            return 1;
        }

        var migrationContext = await BuildManufacturerMigrationContextAsync(config);
        var result = await CreateOrUpdateManufacturerAsync(config, candidate, migrationContext);

        Console.WriteLine($"Manufacturer result: {result.Status}");
        Console.WriteLine($"Parspec id: {result.ParspecManufacturerId?.ToString() ?? "(none)"}");
        if (!string.IsNullOrWhiteSpace(result.Message))
        {
            Console.WriteLine(result.Message);
        }

        return result.Status is "created" or "updated-existing" ? 0 : 1;
    }

    private static async Task<int> RunManufacturersCreateAllAsync(ParspecMigratorConfig config)
    {
        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        Directory.CreateDirectory(config.OutputDirectory);

        var manufacturers = await LoadManufacturerCandidatesAsync(config.BusinessConnectionString);
        var migrationContext = await BuildManufacturerMigrationContextAsync(config);
        var results = new List<ManufacturerMigrationExecutionResult>(manufacturers.Count);

        Console.WriteLine($"Starting bulk manufacturer migration for {manufacturers.Count} active manufacturers.");

        for (var index = 0; index < manufacturers.Count; index++)
        {
            var candidate = manufacturers[index];
            var result = await CreateOrUpdateManufacturerAsync(config, candidate, migrationContext);
            results.Add(result);

            Console.WriteLine($"[{index + 1}/{manufacturers.Count}] {candidate.ErpId} | {candidate.Name} | {result.Status} | Parspec {result.ParspecManufacturerId?.ToString() ?? "-"}");
        }

        var report = new ManufacturerBulkMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            TotalCandidates = manufacturers.Count,
            CreatedCount = results.Count(result => result.Status == "created"),
            UpdatedExistingCount = results.Count(result => result.Status == "updated-existing"),
            FailedCount = results.Count(result => result.Status == "failed"),
            Results = results
        };

        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"manufacturers-create-all.{timestamp}.json");
        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Bulk manufacturer migration complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Created: {report.CreatedCount}");
        Console.WriteLine($"Updated existing: {report.UpdatedExistingCount}");
        Console.WriteLine($"Failed: {report.FailedCount}");

        return report.FailedCount == 0 ? 0 : 1;
    }

    private static async Task<int> RunContactsScanAsync(ParspecMigratorConfig config)
    {
        Directory.CreateDirectory(config.OutputDirectory);

        var report = await BuildContactReportAsync(config.BusinessConnectionString);
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"contacts-scan.{timestamp}.json");

        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Contacts scan complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Total contacts: {report.Summary.TotalContacts}");
        Console.WriteLine($"Contacts with source company link: {report.Summary.ContactsWithCompanyErpId}");
        Console.WriteLine($"Contacts with stable CRM id: {report.Summary.ContactsWithCrmId}");
        Console.WriteLine($"Contacts with email: {report.Summary.ContactsWithEmail}");
        Console.WriteLine($"Contacts with phone: {report.Summary.ContactsWithPhone}");
        Console.WriteLine($"Contacts with job title: {report.Summary.ContactsWithJobTitle}");
        Console.WriteLine($"Contacts with work address: {report.Summary.ContactsWithWorkAddress}");

        return 0;
    }

    private static async Task<int> RunContactsCreateAsync(ParspecMigratorConfig config, string[] args)
    {
        if (args.Length < 1)
        {
            Console.WriteLine("Usage: contacts-create <sourceContactId>");
            return 1;
        }

        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        var sourceContactId = args[0].Trim();
        var contacts = await LoadContactCandidatesAsync(config.BusinessConnectionString);
        var candidate = contacts.FirstOrDefault(contact =>
            string.Equals(contact.SourceContactId, sourceContactId, StringComparison.OrdinalIgnoreCase)
            || string.Equals(contact.CrmId, sourceContactId, StringComparison.OrdinalIgnoreCase));

        if (candidate is null)
        {
            Console.WriteLine($"No contact candidate found for {sourceContactId}.");
            return 1;
        }

        var migrationContext = await BuildContactMigrationContextAsync(config);
        var result = await CreateOrUpdateContactAsync(config, candidate, migrationContext);

        Console.WriteLine($"Contact result: {result.Status}");
        Console.WriteLine($"Parspec id: {result.ParspecContactId?.ToString() ?? "(none)"}");
        if (!string.IsNullOrWhiteSpace(result.Message))
        {
            Console.WriteLine(result.Message);
        }

        return result.Status is "created" or "updated-existing" ? 0 : 1;
    }

    private static async Task<int> RunContactsCreateAllAsync(ParspecMigratorConfig config)
    {
        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        Directory.CreateDirectory(config.OutputDirectory);

        var contacts = await LoadContactCandidatesAsync(config.BusinessConnectionString);
        var migrationContext = await BuildContactMigrationContextAsync(config);
        var results = new List<ContactMigrationExecutionResult>(contacts.Count);

        Console.WriteLine($"Starting bulk contact migration for {contacts.Count} contacts.");

        for (var index = 0; index < contacts.Count; index++)
        {
            var candidate = contacts[index];
            var result = await CreateOrUpdateContactAsync(config, candidate, migrationContext);
            results.Add(result);

            Console.WriteLine($"[{index + 1}/{contacts.Count}] {candidate.SourceContactId} | {candidate.FirstName} {candidate.LastName} | {result.Status} | Parspec {result.ParspecContactId?.ToString() ?? "-"}");
        }

        var report = new ContactBulkMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            TotalCandidates = contacts.Count,
            CreatedCount = results.Count(result => result.Status == "created"),
            UpdatedExistingCount = results.Count(result => result.Status == "updated-existing"),
            FailedCount = results.Count(result => result.Status == "failed"),
            Results = results
        };

        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"contacts-create-all.{timestamp}.json");
        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Bulk contact migration complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Created: {report.CreatedCount}");
        Console.WriteLine($"Updated existing: {report.UpdatedExistingCount}");
        Console.WriteLine($"Failed: {report.FailedCount}");

        return report.FailedCount == 0 ? 0 : 1;
    }

    private static async Task<int> RunLocationsScanAsync(ParspecMigratorConfig config)
    {
        Directory.CreateDirectory(config.OutputDirectory);

        var report = await BuildLocationReportAsync(config.BusinessConnectionString);
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"locations-scan.{timestamp}.json");

        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Locations scan complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Distinct source location codes: {report.SourceCodes.Count}");
        Console.WriteLine($"Users with source location memberships: {report.UsersWithMemberships}");
        Console.WriteLine($"Configured Parspec location mappings: {report.ConfiguredMappings}");

        return 0;
    }

    private static async Task<int> RunUsersProbeApiAsync(ParspecMigratorConfig config)
    {
        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);
        using var request = new HttpRequestMessage(HttpMethod.Get, "v1/users?limit=5");
        using var response = await client.SendAsync(request);
        var body = await response.Content.ReadAsStringAsync();

        Console.WriteLine($"HTTP {(int)response.StatusCode} {response.StatusCode}");
        Console.WriteLine(body);

        return 0;
    }

    private static async Task<int> RunUsersPatchAsync(ParspecMigratorConfig config, string[] args)
    {
        if (args.Length < 2)
        {
            Console.WriteLine("Usage: users-patch <parspecUserId> <oasisUserId>");
            return 1;
        }

        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        if (!int.TryParse(args[0], out var parspecUserId))
        {
            Console.WriteLine($"Invalid Parspec user id: {args[0]}");
            return 1;
        }

        var oasisUserId = args[1];
        var locationMap = config.LocationMappings
            .Where(pair => pair.Value > 0)
            .ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.OrdinalIgnoreCase);

        var users = await LoadUserCandidatesAsync(config.BusinessConnectionString, locationMap);
        var candidate = users.FirstOrDefault(user =>
            string.Equals(user.OasisUserId, oasisUserId, StringComparison.OrdinalIgnoreCase));

        if (candidate is null)
        {
            Console.WriteLine($"No active Oasis user candidate found for {oasisUserId}.");
            return 1;
        }

        if (string.IsNullOrWhiteSpace(candidate.CandidateParspecPatch.ParspecWritableFields.CrmId)
            || string.IsNullOrWhiteSpace(candidate.CandidateParspecPatch.ParspecWritableFields.ErpId))
        {
            Console.WriteLine($"User {oasisUserId} is missing CRM/ERP ids required for Parspec PATCH.");
            return 1;
        }

        var unresolved = candidate.CandidateParspecPatch.UnresolvedFields
            .Where(reason => !reason.Contains("location", StringComparison.OrdinalIgnoreCase))
            .ToList();

        if (unresolved.Count > 0)
        {
            Console.WriteLine("Patch aborted because unresolved non-location fields remain:");
            foreach (var reason in unresolved)
            {
                Console.WriteLine($"  - {reason}");
            }

            return 1;
        }

        var payload = new UserPatchPayload
        {
            CrmId = candidate.CandidateParspecPatch.ParspecWritableFields.CrmId,
            ErpId = candidate.CandidateParspecPatch.ParspecWritableFields.ErpId,
            DefaultLocation = candidate.CandidateParspecPatch.ParspecWritableFields.DefaultLocation,
            LocationAccess = candidate.CandidateParspecPatch.ParspecWritableFields.LocationAccess
        };

        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Patch, $"v1/users/{parspecUserId}")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        Console.WriteLine($"Patched Parspec user {parspecUserId} from Oasis user {oasisUserId}.");
        Console.WriteLine($"Source display name: {candidate.CandidateDisplayName}");
        Console.WriteLine($"HTTP {(int)response.StatusCode} {response.StatusCode}");
        Console.WriteLine(responseBody);

        return response.IsSuccessStatusCode ? 0 : 1;
    }

    private static async Task<int> RunUsersMatchParspecAsync(ParspecMigratorConfig config)
    {
        if (string.IsNullOrWhiteSpace(config.ParspecApiKey))
        {
            Console.WriteLine("Parspec API key is missing. Set PARSPEC_API_KEY or update config.");
            return 1;
        }

        Directory.CreateDirectory(config.OutputDirectory);

        var locationMap = config.LocationMappings
            .Where(pair => pair.Value > 0)
            .ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.OrdinalIgnoreCase);

        var sourceUsers = await LoadUserCandidatesAsync(config.BusinessConnectionString, locationMap);
        var parspecUsers = await LoadParspecUsersAsync(config);
        var report = BuildParspecUserMatchReport(sourceUsers, parspecUsers);
        var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
        var outputPath = Path.Combine(config.OutputDirectory, $"users-match-parspec.{timestamp}.json");

        await File.WriteAllTextAsync(outputPath, JsonSerializer.Serialize(report, JsonOptions));

        Console.WriteLine("Parspec user match complete.");
        Console.WriteLine($"Output: {outputPath}");
        Console.WriteLine($"Parspec users scanned: {report.Summary.ParspecUsersScanned}");
        Console.WriteLine($"Exact name matches: {report.Summary.ExactNameMatches}");
        Console.WriteLine($"Matched Parspec users patch-ready: {report.Summary.PatchReadyMatches}");
        Console.WriteLine($"Unmatched Parspec users: {report.Summary.UnmatchedParspecUsers}");

        return 0;
    }

    private static async Task<List<UserCandidate>> LoadUserCandidatesAsync(
        string businessConnectionString,
        IReadOnlyDictionary<string, int> locationMap)
    {
        const string sql = """
WITH OasisUsers AS
(
    SELECT
        USERID,
        FIRSTNAME,
        MIDDLENAME,
        LASTNAME,
        INITIALS,
        TERRITORYID,
        ACTIVE,
        ACCOUNTID,
        LASTLOGIN,
        HIREDATE,
        TERMINATIONDATE
    FROM OASIS_MACSII.oasis.CHSC_USERS
),
AoUsers AS
(
    SELECT
        Id AS AoUserId,
        Cst_External_Id__c AS ErpUserId,
        IsActive AS AoIsActive,
        Name AS AoName,
        CAST(Workgroup__c AS nvarchar(max)) AS AoWorkgroups
    FROM MACSII_V2.AO.[User]
)
SELECT
    oasis.USERID,
    oasis.FIRSTNAME,
    oasis.MIDDLENAME,
    oasis.LASTNAME,
    oasis.INITIALS,
    oasis.TERRITORYID,
    oasis.ACTIVE,
    oasis.ACCOUNTID,
    oasis.LASTLOGIN,
    oasis.HIREDATE,
    oasis.TERMINATIONDATE,
    ao.AoUserId,
    ao.ErpUserId,
    ao.AoIsActive,
    ao.AoName,
    ao.AoWorkgroups
FROM OasisUsers oasis
LEFT JOIN AoUsers ao ON ao.ErpUserId = oasis.USERID
WHERE oasis.ACTIVE = 'Y'

UNION ALL

SELECT
    NULL AS USERID,
    NULL AS FIRSTNAME,
    NULL AS MIDDLENAME,
    NULL AS LASTNAME,
    NULL AS INITIALS,
    NULL AS TERRITORYID,
    NULL AS ACTIVE,
    NULL AS ACCOUNTID,
    NULL AS LASTLOGIN,
    NULL AS HIREDATE,
    NULL AS TERMINATIONDATE,
    ao.AoUserId,
    ao.ErpUserId,
    ao.AoIsActive,
    ao.AoName,
    ao.AoWorkgroups
FROM AoUsers ao
WHERE ao.AoIsActive = 1
  AND NOT EXISTS
  (
      SELECT 1
      FROM OasisUsers oasis
      WHERE oasis.USERID = ao.ErpUserId
        AND oasis.ACTIVE = 'Y'
  )
ORDER BY USERID, ErpUserId, AoName;
""";

        var results = new List<UserCandidate>();
        await using var connection = new SqlConnection(businessConnectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            var firstName = GetNullableString(reader, "FIRSTNAME");
            var middleName = GetNullableString(reader, "MIDDLENAME");
            var lastName = GetNullableString(reader, "LASTNAME");
            var resolvedName = string.Join(
                " ",
                new[] { firstName, middleName, lastName }
                    .Where(value => !string.IsNullOrWhiteSpace(value)))
                .Trim();

            var sourceErpId = GetNullableString(reader, "USERID");
            var aoErpId = GetNullableString(reader, "ErpUserId");
            var parspecErpId = !string.IsNullOrWhiteSpace(sourceErpId) ? sourceErpId : aoErpId;
            var aoUserId = GetNullableString(reader, "AoUserId");
            var territory = GetNullableString(reader, "TERRITORYID");
            var workgroups = SplitSemicolonList(GetNullableString(reader, "AoWorkgroups"));

            results.Add(new UserCandidate
            {
                OasisUserId = sourceErpId,
                FirstName = firstName,
                MiddleName = middleName,
                LastName = lastName,
                Initials = GetNullableString(reader, "INITIALS"),
                TerritoryId = territory,
                OasisActive = string.Equals(GetNullableString(reader, "ACTIVE"), "Y", StringComparison.OrdinalIgnoreCase),
                AccountId = GetNullableString(reader, "ACCOUNTID"),
                LastLogin = GetNullableDateTime(reader, "LASTLOGIN"),
                HireDate = GetNullableDateTime(reader, "HIREDATE"),
                TerminationDate = GetNullableDateTime(reader, "TERMINATIONDATE"),
                AoUserId = aoUserId,
                AoErpUserId = aoErpId,
                AoIsActive = GetNullableBoolean(reader, "AoIsActive"),
                AoName = GetNullableString(reader, "AoName"),
                AoWorkgroups = workgroups,
                CandidateDisplayName = !string.IsNullOrWhiteSpace(resolvedName) ? resolvedName : GetNullableString(reader, "AoName"),
                CandidateParspecPatch = BuildPatchCandidate(parspecErpId, aoUserId, territory, workgroups, locationMap)
            });
        }

        return results;
    }

    private static UserPatchCandidate BuildPatchCandidate(
        string? erpUserId,
        string? aoUserId,
        string? territoryId,
        IReadOnlyList<string> workgroups,
        IReadOnlyDictionary<string, int> locationMap)
    {
        var unresolved = new List<string>();
        int? defaultLocation = null;
        var locationAccess = new List<int>();

        if (!string.IsNullOrWhiteSpace(territoryId)
            && locationMap.TryGetValue(territoryId, out var defaultLocationId))
        {
            defaultLocation = defaultLocationId;
            locationAccess.Add(defaultLocationId);
        }
        else
        {
            unresolved.Add("defaultLocation: no location mapping yet from Oasis territory/workgroup to Parspec location id");
        }

        if (workgroups.Count == 0)
        {
            unresolved.Add("locationAccess: no AO workgroups available to infer Parspec location ids");
        }
        else
        {
            foreach (var workgroup in workgroups)
            {
                if (locationMap.TryGetValue(workgroup, out var locationId))
                {
                    locationAccess.Add(locationId);
                }
            }

            if (locationAccess.Count == 0)
            {
                unresolved.Add("locationAccess: AO workgroups exist but need lookup to concrete Parspec location ids");
            }
        }

        return new UserPatchCandidate
        {
            ParspecWritableFields = new UserPatchPayload
            {
                CrmId = aoUserId,
                ErpId = erpUserId,
                DefaultLocation = defaultLocation,
                LocationAccess = locationAccess
                    .Distinct()
                    .OrderBy(id => id)
                    .ToList()
            },
            UnresolvedFields = unresolved
        };
    }

    private static async Task<LocationScanReport> BuildLocationReportAsync(string businessConnectionString)
    {
        const string sql = """
WITH Memberships AS
(
    SELECT
        src.USERID,
        src.TERRITORYID,
        CAST('oasis.CHSC_USERTERRITORYACCESS' AS varchar(64)) AS SourceTable
    FROM OASIS_MACSII.oasis.CHSC_USERTERRITORYACCESS src

    UNION ALL

    SELECT
        uw.USERID,
        LTRIM(RTRIM(value)) AS TERRITORYID,
        CAST('MACSII_V2.dbo.UserWorkgroup' AS varchar(64)) AS SourceTable
    FROM MACSII_V2.dbo.UserWorkgroup uw
    CROSS APPLY STRING_SPLIT(uw.WorkGroups, ',')
)
SELECT
    USERID,
    TERRITORYID,
    SourceTable
FROM Memberships
WHERE NULLIF(LTRIM(RTRIM(TERRITORYID)), '') IS NOT NULL
ORDER BY TERRITORYID, USERID, SourceTable;
""";

        var memberships = new List<LocationMembership>();
        await using var connection = new SqlConnection(businessConnectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            memberships.Add(new LocationMembership
            {
                UserId = GetNullableString(reader, "USERID") ?? string.Empty,
                SourceCode = GetNullableString(reader, "TERRITORYID") ?? string.Empty,
                SourceTable = GetNullableString(reader, "SourceTable") ?? string.Empty
            });
        }

        var configured = ParspecMigratorConfig.Load().LocationMappings;
        var sourceCodes = memberships
            .GroupBy(m => m.SourceCode, StringComparer.OrdinalIgnoreCase)
            .Select(group => new SourceLocationCode
            {
                SourceCode = group.Key,
                UserCount = group.Select(x => x.UserId).Distinct(StringComparer.OrdinalIgnoreCase).Count(),
                SourceTables = group.Select(x => x.SourceTable).Distinct(StringComparer.OrdinalIgnoreCase).OrderBy(x => x, StringComparer.OrdinalIgnoreCase).ToList(),
                ConfiguredParspecLocationId = configured.TryGetValue(group.Key, out var id) ? id : null
            })
            .OrderByDescending(item => item.UserCount)
            .ThenBy(item => item.SourceCode, StringComparer.OrdinalIgnoreCase)
            .ToList();

        return new LocationScanReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            UsersWithMemberships = memberships.Select(x => x.UserId).Distinct(StringComparer.OrdinalIgnoreCase).Count(),
            ConfiguredMappings = configured.Count(pair => pair.Value > 0),
            SourceCodes = sourceCodes,
            Memberships = memberships
        };
    }

    private static async Task<IReadOnlyList<ParspecUser>> LoadParspecUsersAsync(ParspecMigratorConfig config)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);
        using var response = await client.GetAsync("v1/users?limit=100");
        var body = await response.Content.ReadAsStringAsync();

        response.EnsureSuccessStatusCode();

        var parsed = JsonSerializer.Deserialize<ParspecUserListResponse>(body, ApiJsonOptions);
        return parsed?.Results ?? Array.Empty<ParspecUser>();
    }

    private static async Task<CompanyMigrationReport> BuildCompanyReportAsync(string businessConnectionString)
    {
        var companies = await LoadCompanyCandidatesAsync(businessConnectionString);
        var fields = BuildCompanyFieldCoverage(companies);
        var resolvedBaseFields = fields.Count(field => field.Status is "direct" or "derived" or "default");
        var summary = new CompanyMigrationSummary
        {
            TotalCompanies = companies.Count,
            TotalBaseFields = fields.Count,
            ResolvedBaseFields = resolvedBaseFields,
            UnresolvedBaseFields = fields.Count - resolvedBaseFields,
            CompaniesWithCrmId = companies.Count(company => !string.IsNullOrWhiteSpace(company.CrmId)),
            CompaniesWithEmail = companies.Count(company => !string.IsNullOrWhiteSpace(company.Email)),
            CompaniesWithBillAddress = companies.Count(company => company.BillToAddress.HasContent),
            CompaniesWithNotes = companies.Count(company => company.HasNotesContent),
            CompaniesWithSoldAddress = companies.Count(company => company.SoldToAddress.HasContent),
            CompaniesWithShipAddress = companies.Count(company => company.ShipToAddress.HasContent),
            CompaniesWithParentReference = companies.Count(company => !string.IsNullOrWhiteSpace(company.ParentErpId)),
            CompaniesWithPhone = companies.Count(company => !string.IsNullOrWhiteSpace(company.Phone)),
            CompaniesWithWebsite = companies.Count(company => !string.IsNullOrWhiteSpace(company.Website))
        };

        return new CompanyMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            Summary = summary,
            FieldCoverage = fields,
            Companies = companies.Take(100).ToList()
        };
    }

    private static async Task<List<CompanyCandidate>> LoadCompanyCandidatesAsync(string businessConnectionString)
    {
        const string sql = """
WITH base AS
(
    SELECT
        a.AccountId,
        a.DISPLAYID,
        a.DISTRIBUTORNAME,
        a.ACTIVE,
        a.ROLE,
        a.CUSTOMERRANK,
        a.SALESUSERID,
        a.SOLDNAME,
        a.SOLDLINE1,
        a.SOLDLINE2,
        a.SOLDCITY,
        a.SOLDSTATE,
        a.SOLDZIP,
        a.SOLDCOUNTRY,
        a.SHIPNAME,
        a.SHIPLINE1,
        a.SHIPLINE2,
        a.SHIPCITY,
        a.SHIPSTATE,
        a.SHIPZIP,
        a.SHIPCOUNTRY,
        a.PHONE,
        a.WEB,
        a.FAX,
        a.PARENTNAME,
        a.PARENTID,
        a.EMAIL,
        a.BILLNAME,
        a.BILLLINE1,
        a.BILLLINE2,
        a.BILLCITY,
        a.BILLSTATE,
        a.BILLZIP,
        a.BILLCOUNTRY,
        a.ORDERENTRYNOTES,
        a.INTERNALNOTES,
        a.TERMTEXT,
        a.INVOICETERMTEXT,
        a.TAXID,
        a.UPDATEDATE,
        ao.Id AS AoAccountId
    FROM src.Account a
    LEFT JOIN AO.Account ao
      ON ao.Cst_External_Id__c = a.AccountId
     AND ao.Cst_Customer_Type__c = a.ROLE
    WHERE a.ACCOUNTTYPE = 'Customer'
      AND a.ACTIVE = 'Active'
)
SELECT *
FROM base
ORDER BY DISTRIBUTORNAME, AccountId;
""";

        var companies = new List<CompanyCandidate>();
        await using var connection = new SqlConnection(businessConnectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            var erpId = GetNullableString(reader, "AccountId");
            var name = GetNullableString(reader, "DISTRIBUTORNAME");
            var businessType = GetNullableString(reader, "ROLE");
            var crmId = GetNullableString(reader, "AoAccountId");
            var outsideSalesCrmId = GetNullableString(reader, "SALESUSERID");

            var soldAddress = new CompanyAddress
            {
                Name = GetNullableString(reader, "SOLDNAME"),
                AddressLine1 = GetNullableString(reader, "SOLDLINE1"),
                AddressLine2 = GetNullableString(reader, "SOLDLINE2"),
                City = GetNullableString(reader, "SOLDCITY"),
                StateOrRegionCode = NormalizeRegionCode(GetNullableString(reader, "SOLDSTATE")),
                PostalCode = GetNullableString(reader, "SOLDZIP"),
                CountryCode = NormalizeCountryCode(GetNullableString(reader, "SOLDCOUNTRY"))
            };

            var billAddress = new CompanyAddress
            {
                Name = GetNullableString(reader, "BILLNAME"),
                AddressLine1 = GetNullableString(reader, "BILLLINE1"),
                AddressLine2 = GetNullableString(reader, "BILLLINE2"),
                City = GetNullableString(reader, "BILLCITY"),
                StateOrRegionCode = NormalizeRegionCode(GetNullableString(reader, "BILLSTATE")),
                PostalCode = GetNullableString(reader, "BILLZIP"),
                CountryCode = NormalizeCountryCode(GetNullableString(reader, "BILLCOUNTRY"))
            };

            var shipAddress = new CompanyAddress
            {
                Name = GetNullableString(reader, "SHIPNAME"),
                AddressLine1 = GetNullableString(reader, "SHIPLINE1"),
                AddressLine2 = GetNullableString(reader, "SHIPLINE2"),
                City = GetNullableString(reader, "SHIPCITY"),
                StateOrRegionCode = NormalizeRegionCode(GetNullableString(reader, "SHIPSTATE")),
                PostalCode = GetNullableString(reader, "SHIPZIP"),
                CountryCode = NormalizeCountryCode(GetNullableString(reader, "SHIPCOUNTRY"))
            };

            companies.Add(new CompanyCandidate
            {
                ErpId = erpId,
                Name = name,
                BusinessType = businessType,
                CrmId = crmId,
                OutsideSalesCrmUserId = outsideSalesCrmId,
                Email = GetNullableString(reader, "EMAIL"),
                Phone = GetNullableString(reader, "PHONE"),
                Website = GetNullableString(reader, "WEB"),
                Fax = GetNullableString(reader, "FAX"),
                ParentErpId = GetNullableString(reader, "PARENTID"),
                ParentName = GetNullableString(reader, "PARENTNAME"),
                SoldToAddress = soldAddress,
                BillToAddress = billAddress,
                ShipToAddress = shipAddress,
                OrderEntryNotes = GetNullableString(reader, "ORDERENTRYNOTES"),
                InternalNotes = GetNullableString(reader, "INTERNALNOTES"),
                TermText = GetNullableString(reader, "TERMTEXT"),
                InvoiceTermText = GetNullableString(reader, "INVOICETERMTEXT"),
                TaxId = GetNullableString(reader, "TAXID"),
                LastUpdated = GetNullableDateTime(reader, "UPDATEDATE"),
                Coverage = BuildCompanyCoverage(
                    erpId,
                    name,
                    businessType,
                    crmId,
                    outsideSalesCrmId,
                    GetNullableString(reader, "EMAIL"),
                    GetNullableString(reader, "PHONE"),
                    GetNullableString(reader, "WEB"),
                    soldAddress,
                    billAddress,
                    shipAddress,
                    GetNullableString(reader, "PARENTID"),
                    GetNullableString(reader, "ORDERENTRYNOTES"),
                    GetNullableString(reader, "INTERNALNOTES"),
                    GetNullableString(reader, "TERMTEXT"),
                    GetNullableString(reader, "INVOICETERMTEXT"))
            });
        }

        return companies;
    }

    private static async Task<ContactMigrationReport> BuildContactReportAsync(string businessConnectionString)
    {
        var contacts = await LoadContactCandidatesAsync(businessConnectionString);
        var fields = BuildContactFieldCoverage(contacts);
        var resolvedBaseFields = fields.Count(field => field.Status is "direct" or "derived" or "default");
        var summary = new ContactMigrationSummary
        {
            TotalContacts = contacts.Count,
            TotalBaseFields = fields.Count,
            ResolvedBaseFields = resolvedBaseFields,
            UnresolvedBaseFields = fields.Count - resolvedBaseFields,
            ContactsWithCompanyErpId = contacts.Count(contact => !string.IsNullOrWhiteSpace(contact.CompanyErpId)),
            ContactsWithCrmId = contacts.Count(contact => !string.IsNullOrWhiteSpace(contact.CrmId)),
            ContactsWithEmail = contacts.Count(contact => !string.IsNullOrWhiteSpace(contact.Email)),
            ContactsWithPhone = contacts.Count(contact => !string.IsNullOrWhiteSpace(SelectPrimaryContactPhone(contact))),
            ContactsWithJobTitle = contacts.Count(contact => !string.IsNullOrWhiteSpace(contact.JobTitle)),
            ContactsWithWorkAddress = contacts.Count(contact => contact.WorkAddress.HasContent),
            ContactsWithHomeAddress = contacts.Count(contact => contact.HomeAddress.HasContent),
            ContactsWithNotes = contacts.Count(contact => !string.IsNullOrWhiteSpace(BuildContactNotes(contact)))
        };

        return new ContactMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            Summary = summary,
            FieldCoverage = fields,
            Contacts = contacts.Take(100).ToList()
        };
    }

    private static async Task<List<ContactCandidate>> LoadContactCandidatesAsync(string businessConnectionString)
    {
        const string sql = """
WITH UnifiedContacts AS (
SELECT
    c.CONTACTID,
    c.EXTERNALID,
    c.OasisContactId,
    c.UPDATEDATE,
    c.FIRSTNAME,
    c.MIDDLENAME,
    c.LASTNAME,
    c.DEPARTMENT,
    c.JOBPOSITION,
    c.PHONE,
    c.EXT,
    c.MOBILE,
    c.FAX,
    c.EMail,
    c.AccountId,
    c.WORKLINE1,
    c.WORKLINE2,
    c.WORKCITY,
    c.WORKSTATE,
    c.WORKZIP,
    c.WORKCOUNTRY,
    c.HOMELINE1,
    c.HOMELINE2,
    c.HOMECITY,
    c.HOMESTATE,
    c.HOMEZIP,
    c.HOMECOUNTRY,
    ao.Id AS AoContactId,
    aoAccount.Cst_External_Id__c AS CompanyErpId,
    aoAccount.Name AS AccountName
FROM SRC.Contact c
LEFT JOIN AO.Contact ao
  ON ao.ExternalId__c = c.CONTACTID
 AND ao.AccountId = c.AccountId
LEFT JOIN AO.Account aoAccount
  ON aoAccount.Id = c.AccountId
LEFT JOIN SRC.Account srcAccount
  ON srcAccount.AccountId = aoAccount.Cst_External_Id__c
WHERE ISNULL(c.AccountId, '') <> ''
  AND ISNULL(c.LASTNAME, '') <> ''
  AND srcAccount.AccountType = 'Customer'
  AND srcAccount.Active = 'Active'

UNION ALL

SELECT
    CONCAT(raw.DBID, ':', raw.CONTACTID) AS CONTACTID,
    CONVERT(varchar(100), raw.CONTACTID) AS EXTERNALID,
    CONCAT(raw.DBID, ':', raw.CONTACTID) AS OasisContactId,
    raw.UPDATEDATE,
    raw.FIRSTNAME,
    raw.MIDDLENAME,
    raw.LASTNAME,
    raw.DEPARTMENT,
    raw.JOBPOSITION,
    NULL AS PHONE,
    NULL AS EXT,
    NULL AS MOBILE,
    NULL AS FAX,
    NULL AS EMail,
    aoAccount.Id AS AccountId,
    raw.WORKLINE1,
    raw.WORKLINE2,
    raw.WORKCITY,
    raw.WORKSTATE,
    raw.WORKZIP,
    raw.WORKCOUNTRY,
    raw.HOMELINE1,
    raw.HOMELINE2,
    raw.HOMECITY,
    raw.HOMESTATE,
    raw.HOMEZIP,
    raw.HOMECOUNTRY,
    ao.Id AS AoContactId,
    aoAccount.Cst_External_Id__c AS CompanyErpId,
    aoAccount.Name AS AccountName
FROM OASIS_MACSII.oasis.CHSC_CONTACTS raw
CROSS APPLY (
    SELECT COALESCE(
        NULLIF(raw.DISTRIBUTORID, ''),
        NULLIF(raw.MANUFACTURERID, ''),
        NULLIF(raw.REPRESENTATIVEID, '')
    ) AS SourceAccountId
) accountKey
LEFT JOIN AO.Account aoAccount
  ON aoAccount.Cst_External_Id__c = accountKey.SourceAccountId
LEFT JOIN AO.Contact ao
  ON ao.ExternalId__c = CONCAT(raw.DBID, ':', raw.CONTACTID)
 AND ao.AccountId = aoAccount.Id
LEFT JOIN SRC.Account srcAccount
  ON srcAccount.AccountId = aoAccount.Cst_External_Id__c
WHERE accountKey.SourceAccountId IS NOT NULL
  AND ISNULL(raw.LASTNAME, '') <> ''
  AND srcAccount.AccountType = 'Customer'
  AND srcAccount.Active = 'Active'
  AND NOT EXISTS (
      SELECT 1
      FROM SRC.Contact existing
      WHERE existing.OasisContactId = CONCAT(raw.DBID, ':', raw.CONTACTID)
  )
)
SELECT
    CONTACTID,
    EXTERNALID,
    OasisContactId,
    UPDATEDATE,
    FIRSTNAME,
    MIDDLENAME,
    LASTNAME,
    DEPARTMENT,
    JOBPOSITION,
    PHONE,
    EXT,
    MOBILE,
    FAX,
    EMail,
    AccountId,
    WORKLINE1,
    WORKLINE2,
    WORKCITY,
    WORKSTATE,
    WORKZIP,
    WORKCOUNTRY,
    HOMELINE1,
    HOMELINE2,
    HOMECITY,
    HOMESTATE,
    HOMEZIP,
    HOMECOUNTRY,
    AoContactId,
    CompanyErpId,
    AccountName
FROM UnifiedContacts
ORDER BY UPDATEDATE DESC, CONTACTID;
""";

        var contacts = new List<ContactCandidate>();
        await using var connection = new SqlConnection(businessConnectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            var sourceContactId = GetNullableString(reader, "CONTACTID");
            var crmId = GetNullableString(reader, "AoContactId") ?? sourceContactId;

            var workAddress = new CompanyAddress
            {
                AddressLine1 = GetNullableString(reader, "WORKLINE1"),
                AddressLine2 = GetNullableString(reader, "WORKLINE2"),
                City = GetNullableString(reader, "WORKCITY"),
                StateOrRegionCode = NormalizeRegionCode(GetNullableString(reader, "WORKSTATE")),
                PostalCode = GetNullableString(reader, "WORKZIP"),
                CountryCode = NormalizeCountryCode(GetNullableString(reader, "WORKCOUNTRY"))
            };

            var homeAddress = new CompanyAddress
            {
                AddressLine1 = GetNullableString(reader, "HOMELINE1"),
                AddressLine2 = GetNullableString(reader, "HOMELINE2"),
                City = GetNullableString(reader, "HOMECITY"),
                StateOrRegionCode = NormalizeRegionCode(GetNullableString(reader, "HOMESTATE")),
                PostalCode = GetNullableString(reader, "HOMEZIP"),
                CountryCode = NormalizeCountryCode(GetNullableString(reader, "HOMECOUNTRY"))
            };

            contacts.Add(new ContactCandidate
            {
                SourceContactId = sourceContactId,
                ExternalId = GetNullableString(reader, "EXTERNALID"),
                OasisContactId = GetNullableString(reader, "OasisContactId"),
                CrmId = crmId,
                CompanyErpId = GetNullableString(reader, "CompanyErpId"),
                CompanyName = GetNullableString(reader, "AccountName"),
                FirstName = GetNullableString(reader, "FIRSTNAME"),
                MiddleName = GetNullableString(reader, "MIDDLENAME"),
                LastName = GetNullableString(reader, "LASTNAME"),
                Department = GetNullableString(reader, "DEPARTMENT"),
                JobTitle = GetNullableString(reader, "JOBPOSITION"),
                Email = GetNullableString(reader, "EMail"),
                Phone = GetNullableString(reader, "PHONE"),
                Extension = GetNullableString(reader, "EXT"),
                Mobile = GetNullableString(reader, "MOBILE"),
                Fax = GetNullableString(reader, "FAX"),
                WorkAddress = workAddress,
                HomeAddress = homeAddress,
                LastUpdated = GetNullableDateTime(reader, "UPDATEDATE")
            });
        }

        return contacts;
    }

    private static IReadOnlyList<DestinationFieldCoverage> BuildContactFieldCoverage(IReadOnlyList<ContactCandidate> contacts)
    {
        var total = contacts.Count;

        return
        [
            new DestinationFieldCoverage("company", "direct", "src.Contact.AccountId -> Parspec company erpId", total, contacts.Count(contact => !string.IsNullOrWhiteSpace(contact.CompanyErpId)), "All source contacts are linked to a source company id."),
            new DestinationFieldCoverage("firstName", "direct", "src.Contact.FIRSTNAME", total, contacts.Count(contact => !string.IsNullOrWhiteSpace(contact.FirstName)), "First name is present for most contacts."),
            new DestinationFieldCoverage("lastName", "direct", "src.Contact.LASTNAME", total, contacts.Count(contact => !string.IsNullOrWhiteSpace(contact.LastName)), "Last name is required in source and available for all migrated contacts."),
            new DestinationFieldCoverage("crmId", "derived", "AO.Contact.Id fallback src.Contact.CONTACTID", total, contacts.Count(contact => !string.IsNullOrWhiteSpace(contact.CrmId)), "Stable contact key is available for almost all contacts from AO.Contact and can fall back to source contact id."),
            new DestinationFieldCoverage("email", "direct", "src.Contact.EMail", total, contacts.Count(contact => !string.IsNullOrWhiteSpace(contact.Email)), "Email coverage is strong."),
            new DestinationFieldCoverage("phone", "derived", "src.Contact.PHONE fallback src.Contact.MOBILE", total, contacts.Count(contact => !string.IsNullOrWhiteSpace(SelectPrimaryContactPhone(contact))), "Phone can come from primary phone or mobile fallback."),
            new DestinationFieldCoverage("jobTitle", "direct", "src.Contact.JOBPOSITION", total, contacts.Count(contact => !string.IsNullOrWhiteSpace(contact.JobTitle)), "Job title coverage is partial but useful."),
            new DestinationFieldCoverage("notes", "derived", "src.Contact.DEPARTMENT / EXT / MOBILE / FAX / HOME*", total, contacts.Count(contact => !string.IsNullOrWhiteSpace(BuildContactNotes(contact))), "Secondary contact attributes can be preserved in notes."),
            new DestinationFieldCoverage("address", "direct", "src.Contact.WORK* fallback inherited company address", total, contacts.Count(contact => contact.WorkAddress.HasContent), "Work address exists for most contacts; otherwise the contact can inherit the company address."),
            new DestinationFieldCoverage("outsideSalesAgent", "unresolved", "No contact-level owner source selected yet", total, 0, "No first-pass contact owner mapping has been chosen yet.")
        ];
    }

    private static async Task<ManufacturerMigrationReport> BuildManufacturerReportAsync(string businessConnectionString)
    {
        var manufacturers = await LoadManufacturerCandidatesAsync(businessConnectionString);
        var fields = BuildManufacturerFieldCoverage(manufacturers);
        var resolvedBaseFields = fields.Count(field => field.Status is "direct" or "derived" or "default");
        var summary = new ManufacturerMigrationSummary
        {
            TotalManufacturers = manufacturers.Count,
            TotalBaseFields = fields.Count,
            ResolvedBaseFields = resolvedBaseFields,
            UnresolvedBaseFields = fields.Count - resolvedBaseFields,
            ManufacturersWithAoAccountId = manufacturers.Count(manufacturer => !string.IsNullOrWhiteSpace(manufacturer.CrmId)),
            ManufacturersWithPhone = manufacturers.Count(manufacturer => !string.IsNullOrWhiteSpace(manufacturer.Phone)),
            ManufacturersWithWebsite = manufacturers.Count(manufacturer => !string.IsNullOrWhiteSpace(manufacturer.Website)),
            ManufacturersWithFax = manufacturers.Count(manufacturer => !string.IsNullOrWhiteSpace(manufacturer.Fax)),
            ManufacturersWithMailAddress = manufacturers.Count(manufacturer => manufacturer.MailAddress.HasContent),
            ManufacturersWithParentReference = manufacturers.Count(manufacturer => !string.IsNullOrWhiteSpace(manufacturer.ParentCrmId))
        };

        return new ManufacturerMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            Summary = summary,
            FieldCoverage = fields,
            Manufacturers = manufacturers
        };
    }

    private static async Task<List<ManufacturerCandidate>> LoadManufacturerCandidatesAsync(string businessConnectionString)
    {
        const string sql = """
SELECT
    a.AccountId,
    a.DISPLAYID,
    a.UPDATEDATE,
    a.DISTRIBUTORNAME,
    a.ACTIVE,
    a.ROLE,
    a.PHONE,
    a.WEB,
    a.FAX,
    a.SOLDNAME,
    a.SOLDLINE1,
    a.SOLDLINE2,
    a.SOLDCITY,
    a.SOLDSTATE,
    a.SOLDZIP,
    a.SOLDCOUNTRY,
    a.PARENTID,
    a.PARENTNAME,
    ao.Id AS AoAccountId
FROM SRC.Account a
LEFT JOIN AO.Account ao
  ON ao.Cst_External_Id__c = a.AccountId
 AND ao.Cst_Customer_Type__c = a.Role
WHERE a.AccountType = 'Manufacturer'
  AND a.Active = 'Active'
ORDER BY a.DISTRIBUTORNAME, a.AccountId;
""";

        var manufacturers = new List<ManufacturerCandidate>();
        await using var connection = new SqlConnection(businessConnectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            var mailAddress = new CompanyAddress
            {
                Name = GetNullableString(reader, "SOLDNAME"),
                AddressLine1 = GetNullableString(reader, "SOLDLINE1"),
                AddressLine2 = GetNullableString(reader, "SOLDLINE2"),
                City = GetNullableString(reader, "SOLDCITY"),
                StateOrRegionCode = NormalizeRegionCode(GetNullableString(reader, "SOLDSTATE")),
                PostalCode = GetNullableString(reader, "SOLDZIP"),
                CountryCode = NormalizeCountryCode(GetNullableString(reader, "SOLDCOUNTRY"))
            };

            manufacturers.Add(new ManufacturerCandidate
            {
                ErpId = GetNullableString(reader, "AccountId"),
                DisplayId = GetNullableString(reader, "DISPLAYID"),
                Name = GetNullableString(reader, "DISTRIBUTORNAME"),
                CrmId = GetNullableString(reader, "AoAccountId"),
                ParentCrmId = GetNullableString(reader, "PARENTID"),
                ParentName = GetNullableString(reader, "PARENTNAME"),
                Phone = GetNullableString(reader, "PHONE"),
                Website = GetNullableString(reader, "WEB"),
                Fax = GetNullableString(reader, "FAX"),
                MailAddress = mailAddress,
                LastUpdated = GetNullableDateTime(reader, "UPDATEDATE")
            });
        }

        return manufacturers;
    }

    private static IReadOnlyList<DestinationFieldCoverage> BuildManufacturerFieldCoverage(IReadOnlyList<ManufacturerCandidate> manufacturers)
    {
        var total = manufacturers.Count;

        return
        [
            new DestinationFieldCoverage("erpId", "direct", "src.Account.AccountId", total, manufacturers.Count(manufacturer => !string.IsNullOrWhiteSpace(manufacturer.ErpId)), "Manufacturer ERP id is available for all active rows."),
            new DestinationFieldCoverage("name", "direct", "src.Account.DISTRIBUTORNAME", total, manufacturers.Count(manufacturer => !string.IsNullOrWhiteSpace(manufacturer.Name)), "Manufacturer display name is available for all active rows."),
            new DestinationFieldCoverage("address", "direct", "src.Account.SOLD* fields", total, manufacturers.Count(manufacturer => manufacturer.MailAddress.HasContent), "Mailing address is broadly available from the sold-to fields in the business layer."),
            new DestinationFieldCoverage("website", "direct", "src.Account.WEB", total, manufacturers.Count(manufacturer => !string.IsNullOrWhiteSpace(manufacturer.Website)), "Website coverage is partial but clean."),
            new DestinationFieldCoverage("visibleToAllLocations", "default", "Migration policy default", total, total, "Manufacturers can default to visible to all locations for first pass."),
            new DestinationFieldCoverage("visibleToLocations", "default", "Migration policy default", total, total, "No per-location manufacturer scoping selected for first pass."),
            new DestinationFieldCoverage("active", "default", "src.Account.Active = 'Active'", total, total, "Only active manufacturer rows are selected for the first pass."),
            new DestinationFieldCoverage("abbreviations", "derived", "src.Account.DISPLAYID", total, manufacturers.Count(manufacturer => !string.IsNullOrWhiteSpace(manufacturer.DisplayId)), "Display id can seed a first-pass abbreviation list."),
            new DestinationFieldCoverage("parspecManufacturerId", "unresolved", "No source selected yet", total, 0, "Needs mapping to Parspec canonical manufacturer catalog if required."),
            new DestinationFieldCoverage("paymentTerms", "unresolved", "No source selected yet", total, 0, "No payment terms field is currently surfaced in src.Account."),
            new DestinationFieldCoverage("ediVendor", "unresolved", "No source selected yet", total, 0, "No first-pass EDI flag identified yet."),
            new DestinationFieldCoverage("incentive", "unresolved", "No source selected yet", total, 0, "No first-pass incentive flag identified yet.")
        ];
    }

    private static async Task<ProjectMigrationReport> BuildProjectReportAsync(
        string businessConnectionString,
        IReadOnlyDictionary<string, int> locationMappings)
    {
        var projects = await LoadProjectCandidatesAsync(businessConnectionString, locationMappings);
        var stakeholderCandidates = await LoadProjectStakeholderCandidatesAsync(businessConnectionString);
        var stakeholderProjectIds = stakeholderCandidates
            .Select(candidate => candidate.ProjectErpId)
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        var fields = BuildProjectFieldCoverage(projects, stakeholderProjectIds);
        var resolvedBaseFields = fields.Count(field => field.Status is "direct" or "derived" or "default");
        var summary = new ProjectMigrationSummary
        {
            TotalProjects = projects.Count,
            TotalBaseFields = fields.Count,
            ResolvedBaseFields = resolvedBaseFields,
            UnresolvedBaseFields = fields.Count - resolvedBaseFields,
            ProjectsWithErpId = projects.Count(project => !string.IsNullOrWhiteSpace(project.ErpId)),
            ProjectsWithCrmId = projects.Count(project => !string.IsNullOrWhiteSpace(project.CrmId)),
            ProjectsWithLocationMapping = projects.Count(project => project.LocationId.HasValue),
            ProjectsWithOwner = projects.Count(project => !string.IsNullOrWhiteSpace(project.OwnerUserId)),
            ProjectsWithQuoteDistributor = projects.Count(project => !string.IsNullOrWhiteSpace(project.QuoteDistributorId)),
            ProjectsWithCustomerContact = projects.Count(project => !string.IsNullOrWhiteSpace(project.CustomerContactId)),
            ProjectsWithMarketVertical = projects.Count(project => !string.IsNullOrWhiteSpace(project.MarketVertical)),
            ProjectsWithStakeholders = projects.Count(project => !string.IsNullOrWhiteSpace(project.ErpId) && stakeholderProjectIds.Contains(project.ErpId))
        };

        return new ProjectMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            Summary = summary,
            FieldCoverage = fields,
            Projects = projects.Take(100).ToList()
        };
    }

    private static async Task<OpportunityMigrationReport> BuildOpportunityReportAsync(string businessConnectionString)
    {
        var opportunities = await LoadOpportunityCandidatesAsync(businessConnectionString);
        var fields = BuildOpportunityFieldCoverage(opportunities);
        var resolvedBaseFields = fields.Count(field => !string.Equals(field.Status, "unresolved", StringComparison.OrdinalIgnoreCase));

        return new OpportunityMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            Summary = new OpportunityMigrationSummary
            {
                TotalOpportunities = opportunities.Count,
                TotalBaseFields = fields.Count,
                ResolvedBaseFields = resolvedBaseFields,
                UnresolvedBaseFields = fields.Count - resolvedBaseFields,
                OpportunitiesWithProjectErpId = opportunities.Count(opportunity => !string.IsNullOrWhiteSpace(opportunity.ProjectErpId)),
                OpportunitiesWithCrmId = opportunities.Count(opportunity => !string.IsNullOrWhiteSpace(opportunity.CrmId)),
                OpportunitiesWithQuoteDueDate = opportunities.Count(opportunity => opportunity.QuoteDueDate.HasValue),
                OpportunitiesWithSubmittalDueDate = opportunities.Count(opportunity => opportunity.SubmittalDueDate.HasValue),
                OpportunitiesWithQuoter = opportunities.Count(opportunity => !string.IsNullOrWhiteSpace(opportunity.QuoterAoUserId))
            },
            FieldCoverage = fields,
            Opportunities = opportunities
        };
    }

    private static async Task<BomMigrationReport> BuildBomReportAsync(string businessConnectionString)
    {
        var boms = await LoadBomCandidatesAsync(businessConnectionString);
        var fields = BuildBomFieldCoverage(boms);
        var resolvedBaseFields = fields.Count(field => !string.Equals(field.Status, "unresolved", StringComparison.OrdinalIgnoreCase));

        return new BomMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            Summary = new BomMigrationSummary
            {
                TotalBoms = boms.Count,
                TotalBaseFields = fields.Count,
                ResolvedBaseFields = resolvedBaseFields,
                UnresolvedBaseFields = fields.Count - resolvedBaseFields,
                BomsWithCrmId = boms.Count(bom => !string.IsNullOrWhiteSpace(bom.CrmId)),
                BomsWithName = boms.Count(bom => !string.IsNullOrWhiteSpace(bom.Name)),
                BomsWithSalesAgent = boms.Count(bom => !string.IsNullOrWhiteSpace(bom.SalesAgentAoUserId)),
                BomsWithPrimaryContact = boms.Count(bom => !string.IsNullOrWhiteSpace(bom.PrimaryContactSourceId)),
                BomsWithSecondaryContact = boms.Count(bom => !string.IsNullOrWhiteSpace(bom.SecondaryContactSourceId))
            },
            FieldCoverage = fields,
            Boms = boms
        };
    }

    private static async Task<BomLineMigrationReport> BuildBomLineReportAsync(string businessConnectionString)
    {
        var bomLines = await LoadBomLineCandidatesAsync(businessConnectionString);
        var fields = BuildBomLineFieldCoverage(bomLines);
        var resolvedBaseFields = fields.Count(field => !string.Equals(field.Status, "unresolved", StringComparison.OrdinalIgnoreCase));

        return new BomLineMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            Summary = new BomLineMigrationSummary
            {
                TotalBomLines = bomLines.Count,
                TotalBaseFields = fields.Count,
                ResolvedBaseFields = resolvedBaseFields,
                UnresolvedBaseFields = fields.Count - resolvedBaseFields,
                LinesWithBomCrmId = bomLines.Count(line => !string.IsNullOrWhiteSpace(line.BomCrmId)),
                LinesWithErpLineId = bomLines.Count(line => !string.IsNullOrWhiteSpace(line.ErpLineId)),
                LinesWithManufacturerErpId = bomLines.Count(line => !string.IsNullOrWhiteSpace(line.ManufacturerErpId)),
                LinesWithModelNumber = bomLines.Count(line => !string.IsNullOrWhiteSpace(line.ModelNumber)),
                LinesWithDescription = bomLines.Count(line => !string.IsNullOrWhiteSpace(line.Description)),
                LinesWithQuantity = bomLines.Count(line => line.Quantity.HasValue),
                LinesWithExtendedSellAmount = bomLines.Count(line => line.ExtendedSellAmount.HasValue),
                LinesWithUnitSellAmount = bomLines.Count(line => line.UnitSellAmount.HasValue),
                LinesWithType = bomLines.Count(line => !string.IsNullOrWhiteSpace(line.Type))
            },
            FieldCoverage = fields,
            BomLines = bomLines.Take(250).ToList()
        };
    }

    private static async Task<BomMigrationContext> BuildBomMigrationContextAsync(
        ParspecMigratorConfig config,
        IReadOnlyDictionary<string, int> locationMap)
    {
        var existingProjects = await LoadAllParspecProjectsAsync(config);
        var existingCompanies = await LoadAllParspecCompaniesAsync(config);
        var sourceUsers = await LoadUserCandidatesAsync(config.BusinessConnectionString, locationMap);
        var parspecUsers = await LoadParspecUsersAsync(config);
        var sourceContacts = await LoadContactCandidatesAsync(config.BusinessConnectionString);
        var existingContacts = await LoadAllParspecContactsAsync(config);
        var stakeholderCandidates = await LoadProjectStakeholderCandidatesAsync(config.BusinessConnectionString);

        return new BomMigrationContext
        {
            ExistingProjectsByErpId = existingProjects
                .Where(project => !string.IsNullOrWhiteSpace(project.ErpId))
                .GroupBy(project => project.ErpId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingOpportunitiesByProjectId = new Dictionary<int, Dictionary<string, ParspecOpportunity>>(),
            ExistingOpportunitiesByProjectIdAndTitle = new Dictionary<int, Dictionary<string, ParspecOpportunity>>(),
            ExistingBomsByOpportunityId = new Dictionary<int, Dictionary<string, ParspecBom>>(),
            ExistingBomsByOpportunityIdAndName = new Dictionary<int, Dictionary<string, ParspecBom>>(),
            ExistingCompaniesByErpId = existingCompanies
                .Where(company => !string.IsNullOrWhiteSpace(company.ErpId))
                .GroupBy(company => company.ErpId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingContactsByCrmId = existingContacts
                .Where(contact => !string.IsNullOrWhiteSpace(contact.CrmId))
                .GroupBy(contact => contact.CrmId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            SourceContactsBySourceContactId = sourceContacts
                .Where(contact => !string.IsNullOrWhiteSpace(contact.SourceContactId))
                .GroupBy(contact => contact.SourceContactId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            StakeholdersByProjectErpId = stakeholderCandidates
                .Where(candidate => !string.IsNullOrWhiteSpace(candidate.ProjectErpId))
                .GroupBy(candidate => candidate.ProjectErpId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => (IReadOnlyList<ProjectStakeholderCandidate>)group.ToList(), StringComparer.OrdinalIgnoreCase),
            SourceUsers = sourceUsers,
            ParspecUsers = parspecUsers
        };
    }

    private static async Task<BomMigrationExecutionResult> CreateOrUpdateBomAsync(
        ParspecMigratorConfig config,
        BomCandidate candidate,
        BomMigrationContext context)
    {
        if (string.IsNullOrWhiteSpace(candidate.ProjectErpId)
            || !context.ExistingProjectsByErpId.TryGetValue(candidate.ProjectErpId, out var project))
        {
            return new BomMigrationExecutionResult
            {
                SourceProjectErpId = candidate.ProjectErpId,
                SourceQuoteId = candidate.QuoteId,
                SourceName = candidate.Name,
                Status = "failed",
                Message = $"No Parspec project found for source project erpId {candidate.ProjectErpId ?? "(blank)"}."
            };
        }

        await EnsureProjectOpportunitiesLoadedAsync(config, project.Id, context);

        var parentOpportunityCrmId = BuildOpportunityCrmId(candidate.DbId, candidate.QuoteId);
        if (string.IsNullOrWhiteSpace(parentOpportunityCrmId)
            || !context.ExistingOpportunitiesByProjectId.TryGetValue(project.Id, out var byCrmId)
            || !byCrmId.TryGetValue(parentOpportunityCrmId, out var opportunity))
        {
            return new BomMigrationExecutionResult
            {
                SourceProjectErpId = candidate.ProjectErpId,
                SourceQuoteId = candidate.QuoteId,
                SourceName = candidate.Name,
                Status = "failed",
                Message = $"No Parspec opportunity found for source quote crmId {parentOpportunityCrmId ?? "(blank)"} under project {candidate.ProjectErpId ?? "(blank)"}."
            };
        }

        await EnsureOpportunityBomsLoadedAsync(config, project.Id, opportunity.Id, context);

        var payload = BuildBomPayload(candidate, context);
        var existingBom = FindExistingBom(project.Id, opportunity.Id, payload, context);
        if (existingBom is not null)
        {
            return await PatchParspecBomAsync(config, project.Id, opportunity.Id, existingBom.Id, candidate, payload);
        }

        var createResult = await CreateParspecBomAsync(config, project.Id, opportunity.Id, candidate, payload);
        if (createResult.Status == "created" && createResult.ParspecBomId.HasValue)
        {
            RegisterBomInContext(project.Id, opportunity.Id, new ParspecBom
            {
                Id = createResult.ParspecBomId.Value,
                CrmId = payload.CrmId,
                Name = payload.Name
            }, context);
        }

        return createResult;
    }

    private static BomV2Payload BuildBomPayload(BomCandidate candidate, BomMigrationContext context)
    {
        return new BomV2Payload
        {
            CrmId = candidate.CrmId ?? string.Empty,
            Name = candidate.Name ?? string.Empty,
            SalesAgent = ResolveParspecUserId(candidate.SalesAgentAoUserId, context.SourceUsers, context.ParspecUsers),
            PrimaryContact = ResolveBomContactReference(
                candidate.ProjectErpId,
                candidate.PrimaryContactCompanyErpId,
                candidate.PrimaryContactSourceId,
                context),
            SecondaryContact = ResolveBomContactReference(
                candidate.ProjectErpId,
                candidate.SecondaryContactCompanyErpId,
                candidate.SecondaryContactSourceId,
                context)
        };
    }

    private static BomContactRef? ResolveBomContactReference(
        string? projectErpId,
        string? companyErpId,
        string? sourceContactKey,
        BomMigrationContext context)
    {
        var explicitCompanyContact = ResolveBomCompanyReference(companyErpId, sourceContactKey, context);
        if (explicitCompanyContact is not null)
        {
            return explicitCompanyContact;
        }

        var stakeholderContact = ResolveBomStakeholderContact(projectErpId, companyErpId, context);
        if (stakeholderContact is not null)
        {
            return stakeholderContact;
        }

        var normalizedKey = NullIfWhiteSpace(sourceContactKey);
        if (normalizedKey is null)
        {
            return null;
        }

        var contactIdOnly = normalizedKey.Contains(':', StringComparison.Ordinal)
            ? normalizedKey[(normalizedKey.LastIndexOf(':') + 1)..]
            : normalizedKey;

        if (!TryResolveSourceContactCandidate(normalizedKey, contactIdOnly, context, out var sourceContact)
            || string.IsNullOrWhiteSpace(sourceContact.CrmId)
            || !context.ExistingContactsByCrmId.TryGetValue(sourceContact.CrmId, out var parspecContact))
        {
            return null;
        }

        return new BomContactRef
        {
            Company = parspecContact.Company,
            Contact = parspecContact.Id
        };
    }

    private static BomContactRef? ResolveBomCompanyReference(
        string? companyErpId,
        string? sourceContactKey,
        BomMigrationContext context)
    {
        var normalizedCompanyErpId = NullIfWhiteSpace(companyErpId);
        if (normalizedCompanyErpId is null
            || !context.ExistingCompaniesByErpId.TryGetValue(normalizedCompanyErpId, out var parspecCompany))
        {
            return null;
        }

        var contactId = ResolveBomCompanyContactId(sourceContactKey, context);

        return new BomContactRef
        {
            Company = parspecCompany.Id,
            Contact = contactId
        };
    }

    private static BomContactRef? ResolveBomStakeholderContact(
        string? projectErpId,
        string? companyErpId,
        BomMigrationContext context)
    {
        var normalizedProjectErpId = NullIfWhiteSpace(projectErpId);
        var normalizedCompanyErpId = NullIfWhiteSpace(companyErpId);
        if (normalizedProjectErpId is null
            || normalizedCompanyErpId is null
            || !context.StakeholdersByProjectErpId.TryGetValue(normalizedProjectErpId, out var stakeholders))
        {
            return null;
        }

        var stakeholder = stakeholders.FirstOrDefault(candidate =>
            string.Equals(candidate.AccountErpId, normalizedCompanyErpId, StringComparison.OrdinalIgnoreCase));

        if (stakeholder is null
            || !context.ExistingCompaniesByErpId.TryGetValue(normalizedCompanyErpId, out var parspecCompany))
        {
            return null;
        }

        var parspecContactId = ResolveStakeholderParspecContactId(stakeholder, context);

        return new BomContactRef
        {
            Company = parspecCompany.Id,
            Contact = parspecContactId
        };
    }

    private static int? ResolveStakeholderParspecContactId(
        ProjectStakeholderCandidate stakeholder,
        BomMigrationContext context)
    {
        if (!string.IsNullOrWhiteSpace(stakeholder.ContactCrmId)
            && context.ExistingContactsByCrmId.TryGetValue(stakeholder.ContactCrmId, out var byCrmId))
        {
            return byCrmId.Id;
        }

        if (!string.IsNullOrWhiteSpace(stakeholder.ContactExternalId)
            && context.SourceContactsBySourceContactId.TryGetValue(stakeholder.ContactExternalId, out var sourceContact)
            && !string.IsNullOrWhiteSpace(sourceContact.CrmId)
            && context.ExistingContactsByCrmId.TryGetValue(sourceContact.CrmId, out var bySourceContact))
        {
            return bySourceContact.Id;
        }

        return null;
    }

    private static int? ResolveBomCompanyContactId(string? sourceContactKey, BomMigrationContext context)
    {
        var normalizedKey = NullIfWhiteSpace(sourceContactKey);
        if (normalizedKey is null)
        {
            return null;
        }

        var contactIdOnly = normalizedKey.Contains(':', StringComparison.Ordinal)
            ? normalizedKey[(normalizedKey.LastIndexOf(':') + 1)..]
            : normalizedKey;

        if (!TryResolveSourceContactCandidate(normalizedKey, contactIdOnly, context, out var sourceContact)
            || string.IsNullOrWhiteSpace(sourceContact.CrmId)
            || !context.ExistingContactsByCrmId.TryGetValue(sourceContact.CrmId, out var parspecContact))
        {
            return null;
        }

        return parspecContact.Id;
    }

    private static bool TryResolveSourceContactCandidate(
        string normalizedKey,
        string contactIdOnly,
        BomMigrationContext context,
        out ContactCandidate sourceContact)
    {
        if (context.SourceContactsBySourceContactId.TryGetValue(normalizedKey, out sourceContact!))
        {
            return true;
        }

        if (!string.IsNullOrWhiteSpace(contactIdOnly)
            && context.SourceContactsBySourceContactId.TryGetValue(contactIdOnly, out sourceContact!))
        {
            return true;
        }

        sourceContact = null!;
        return false;
    }

    private static async Task<List<OpportunityCandidate>> LoadOpportunityCandidatesAsync(string businessConnectionString)
    {
        const string sql = """
SELECT
    b.DBID,
    b.ProjectExternalId,
    b.ProjectId,
    b.QuoteId,
    b.BidDate,
    b.BidStatus,
    b.BidName,
    b.QuoteUserId,
    b.Sell,
    b.QuoteLineCount,
    p.ProjectName,
    p.ProjectCoordinator,
    p.ProjectRank,
    q.EXPIRATIONDATE
FROM src.Bid AS b
LEFT JOIN src.Project AS p
    ON p.ExternalId = b.ProjectExternalId
LEFT JOIN OASIS_MACSII.oasis.CHSC_QUOTE AS q
    ON q.DBID = b.DBID
   AND q.QUOTEID = b.QuoteId
WHERE ISNULL(b.ProjectExternalId, '') <> ''
ORDER BY b.ProjectExternalId, b.QuoteId;
""";

        var opportunities = new List<OpportunityCandidate>();
        await using var connection = new SqlConnection(businessConnectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            var dbId = GetNullableString(reader, "DBID");
            var quoteId = GetNullableString(reader, "QuoteId");
            var bidName = NullIfWhiteSpace(GetNullableString(reader, "BidName"));
            var projectName = NullIfWhiteSpace(GetNullableString(reader, "ProjectName"));

            opportunities.Add(new OpportunityCandidate
            {
                DbId = dbId,
                ProjectErpId = GetNullableString(reader, "ProjectExternalId"),
                SourceProjectId = GetNullableString(reader, "ProjectId"),
                QuoteId = quoteId,
                CrmId = BuildOpportunityCrmId(dbId, quoteId),
                Title = bidName ?? projectName ?? $"Quote {quoteId}",
                BidStatus = GetNullableString(reader, "BidStatus"),
                QuoteDueDate = GetNullableDateTime(reader, "BidDate"),
                SubmittalDueDate = GetNullableDateTime(reader, "EXPIRATIONDATE"),
                QuoterAoUserId = GetNullableString(reader, "QuoteUserId"),
                ProjectManagerAoUserId = GetNullableString(reader, "ProjectCoordinator"),
                EstimatedValue = GetNullableDecimal(reader, "Sell"),
                QuoteLineCount = GetNullableDecimal(reader, "QuoteLineCount"),
                ProjectRank = GetNullableString(reader, "ProjectRank"),
                ProjectName = projectName
            });
        }

        return opportunities;
    }

    private static async Task<List<BomCandidate>> LoadBomCandidatesAsync(string businessConnectionString)
    {
        const string sql = """
SELECT
    qi.DBID,
    qi.QuoteId,
    COUNT(*) AS LineCount,
    SUM(CASE WHEN qi.Quantity IS NULL THEN 0 ELSE 1 END) AS LinesWithQuantity,
    SUM(CASE WHEN qi.Sell IS NULL THEN 0 ELSE 1 END) AS LinesWithSell,
    b.ProjectExternalId,
    b.ProjectId,
    b.BidName,
    b.QuoteUserId,
    p.ProjectCoordinator,
    p.ProjectName,
    p.CustomerContactId,
    p.QuoteDistributorId,
    primaryQc.CONTACTDBID AS PrimaryCustomerContactDbId,
    primaryQc.CONTACTID AS PrimaryCustomerContactId,
    primaryQc.DISTRIBUTORID AS PrimaryCustomerCompanyId,
    primaryQdc.CONTACTDBID AS PrimaryContactDbId,
    primaryQdc.CONTACTID AS PrimaryContactId,
    primaryQdc.DISTRIBUTORID AS PrimaryContactDistributorId,
    secondaryQc.CONTACTDBID AS SecondaryCustomerContactDbId,
    secondaryQc.CONTACTID AS SecondaryCustomerContactId,
    secondaryQc.DISTRIBUTORID AS SecondaryCustomerCompanyId,
    secondaryQdc.CONTACTDBID AS SecondaryContactDbId,
    secondaryQdc.CONTACTID AS SecondaryContactId,
    secondaryQdc.DISTRIBUTORID AS SecondaryContactDistributorId
FROM src.QuoteItem AS qi
JOIN src.Bid AS b
    ON b.DBID = qi.DBID
   AND b.QuoteId = qi.QuoteId
LEFT JOIN src.Project AS p
    ON p.ExternalId = b.ProjectExternalId
OUTER APPLY
(
    SELECT TOP (1)
        qc.CONTACTDBID,
        qc.CONTACTID,
        qc.DISTRIBUTORID
    FROM OASIS_MACSII.oasis.CHSC_QUOTECONTACT AS qc
    JOIN src.Account AS qa
        ON qa.AccountId = qc.DISTRIBUTORID
    WHERE qc.DBID = qi.DBID
      AND qc.QUOTEID = qi.QuoteId
      AND ISNULL(qc.DISTRIBUTORID, '') <> ''
      AND qc.ROLE = 'Distributor'
      AND qa.ROLE = 'Distributor'
      AND ISNULL(qc.FREEFORMDESCRIPTION, '') <> 'INACTIVE'
    ORDER BY
        ISNULL(qc.INFLUENCE, 0) DESC,
        qc.SEQUENCE,
        qc.DISTRIBUTORID,
        qc.CONTACTDBID,
        qc.CONTACTID
) AS primaryQc
OUTER APPLY
(
    SELECT TOP (1)
        qdc.CONTACTDBID,
        qdc.CONTACTID,
        qdc.DISTRIBUTORID
    FROM OASIS_MACSII.oasis.CHSC_QUOTEDISTRIBUTORCONTACT AS qdc
    JOIN src.Account AS qda
        ON qda.AccountId = qdc.DISTRIBUTORID
    WHERE qdc.DBID = qi.DBID
      AND qdc.QUOTEID = qi.QuoteId
      AND qdc.CONTACTID IS NOT NULL
      AND qda.ROLE = 'Distributor'
    ORDER BY qdc.UpdateDate_s DESC, qdc.DISTRIBUTORID, qdc.CONTACTDBID, qdc.CONTACTID
) AS primaryQdc
OUTER APPLY
(
    SELECT TOP (1)
        qc.CONTACTDBID,
        qc.CONTACTID,
        qc.DISTRIBUTORID
    FROM OASIS_MACSII.oasis.CHSC_QUOTECONTACT AS qc
    JOIN src.Account AS qa
        ON qa.AccountId = qc.DISTRIBUTORID
    WHERE qc.DBID = qi.DBID
      AND qc.QUOTEID = qi.QuoteId
      AND ISNULL(qc.DISTRIBUTORID, '') <> ''
      AND qc.ROLE = 'Distributor'
      AND qa.ROLE = 'Distributor'
      AND ISNULL(qc.FREEFORMDESCRIPTION, '') <> 'INACTIVE'
      AND (
            primaryQc.DISTRIBUTORID IS NULL
            OR qc.DISTRIBUTORID <> primaryQc.DISTRIBUTORID
            OR ISNULL(qc.CONTACTDBID, '') <> ISNULL(primaryQc.CONTACTDBID, '')
            OR ISNULL(qc.CONTACTID, 0) <> ISNULL(primaryQc.CONTACTID, 0)
          )
    ORDER BY
        ISNULL(qc.INFLUENCE, 0) DESC,
        qc.SEQUENCE,
        qc.DISTRIBUTORID,
        qc.CONTACTDBID,
        qc.CONTACTID
) AS secondaryQc
OUTER APPLY
(
    SELECT TOP (1)
        qdc.CONTACTDBID,
        qdc.CONTACTID,
        qdc.DISTRIBUTORID
    FROM OASIS_MACSII.oasis.CHSC_QUOTEDISTRIBUTORCONTACT AS qdc
    JOIN src.Account AS qda
        ON qda.AccountId = qdc.DISTRIBUTORID
    WHERE qdc.DBID = qi.DBID
      AND qdc.QUOTEID = qi.QuoteId
      AND qdc.CONTACTID IS NOT NULL
      AND qda.ROLE = 'Distributor'
      AND (
            primaryQdc.CONTACTID IS NULL
            OR qdc.CONTACTID <> primaryQdc.CONTACTID
            OR ISNULL(qdc.CONTACTDBID, '') <> ISNULL(primaryQdc.CONTACTDBID, '')
          )
    ORDER BY qdc.UpdateDate_s DESC, qdc.DISTRIBUTORID, qdc.CONTACTDBID, qdc.CONTACTID
) AS secondaryQdc
GROUP BY
    qi.DBID,
    qi.QuoteId,
    b.ProjectExternalId,
    b.ProjectId,
    b.BidName,
    b.QuoteUserId,
    p.ProjectCoordinator,
    p.ProjectName,
    p.CustomerContactId,
    p.QuoteDistributorId,
    primaryQc.CONTACTDBID,
    primaryQc.CONTACTID,
    primaryQc.DISTRIBUTORID,
    primaryQdc.CONTACTDBID,
    primaryQdc.CONTACTID,
    primaryQdc.DISTRIBUTORID,
    secondaryQc.CONTACTDBID,
    secondaryQc.CONTACTID,
    secondaryQc.DISTRIBUTORID,
    secondaryQdc.CONTACTDBID,
    secondaryQdc.CONTACTID,
    secondaryQdc.DISTRIBUTORID
ORDER BY b.ProjectExternalId, qi.QuoteId;
""";

        var boms = new List<BomCandidate>();
        await using var connection = new SqlConnection(businessConnectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            var dbId = GetNullableString(reader, "DBID");
            var quoteId = GetNullableString(reader, "QuoteId");
            var bidName = NullIfWhiteSpace(GetNullableString(reader, "BidName"));
            var projectName = NullIfWhiteSpace(GetNullableString(reader, "ProjectName"));

            boms.Add(new BomCandidate
            {
                DbId = dbId,
                QuoteId = quoteId,
                ProjectErpId = GetNullableString(reader, "ProjectExternalId"),
                SourceProjectId = GetNullableString(reader, "ProjectId"),
                SourceBidId = dbId is null || quoteId is null ? null : $"{dbId}:{quoteId}",
                CrmId = BuildBomCrmId(dbId, quoteId),
                Name = bidName ?? projectName ?? $"BOM {quoteId}",
                SalesAgentAoUserId = GetNullableString(reader, "QuoteUserId"),
                PrimaryContactSourceId = BuildSourceContactKey(GetNullableString(reader, "PrimaryCustomerContactDbId"), GetNullableString(reader, "PrimaryCustomerContactId"))
                    ?? BuildSourceContactKey(GetNullableString(reader, "PrimaryContactDbId"), GetNullableString(reader, "PrimaryContactId")),
                PrimaryContactCompanyErpId = GetNullableString(reader, "PrimaryCustomerCompanyId")
                    ?? GetNullableString(reader, "PrimaryContactDistributorId"),
                SecondaryContactSourceId = BuildSourceContactKey(GetNullableString(reader, "SecondaryCustomerContactDbId"), GetNullableString(reader, "SecondaryCustomerContactId"))
                    ?? BuildSourceContactKey(GetNullableString(reader, "SecondaryContactDbId"), GetNullableString(reader, "SecondaryContactId")),
                SecondaryContactCompanyErpId = GetNullableString(reader, "SecondaryCustomerCompanyId")
                    ?? GetNullableString(reader, "SecondaryContactDistributorId"),
                ProjectManagerAoUserId = GetNullableString(reader, "ProjectCoordinator"),
                LineCount = GetNullableInt(reader, "LineCount") ?? 0,
                LinesWithQuantity = GetNullableInt(reader, "LinesWithQuantity") ?? 0,
                LinesWithSell = GetNullableInt(reader, "LinesWithSell") ?? 0
            });
        }

        return boms;
    }

    private static async Task<List<BomLineCandidate>> LoadBomLineCandidatesAsync(string businessConnectionString)
    {
        const string sql = """
SELECT
    qi.DBID,
    qi.QuoteId,
    qi.ItemNumber,
    qi.LineUID,
    qi.BidId,
    qi.ProjectId,
    b.ProjectExternalId,
    qi.ManufacturerId,
    qi.Type,
    qi.PartNumber,
    qi.Description,
    qi.Quantity,
    qi.Sell,
    qi.Book,
    qi.Base,
    qi.OBase,
    qi.Level1,
    qi.Level2,
    qi.Level3,
    qi.BidStatus,
    qi.UpdateDate
FROM src.QuoteItem AS qi
JOIN src.Bid AS b
    ON b.DBID = qi.DBID
   AND b.QuoteId = qi.QuoteId
ORDER BY
    b.ProjectExternalId,
    qi.QuoteId,
    qi.ItemNumber,
    qi.LineUID;
""";

        var bomLines = new List<BomLineCandidate>();
        await using var connection = new SqlConnection(businessConnectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            var dbId = GetNullableString(reader, "DBID");
            var quoteId = GetNullableString(reader, "QuoteId");
            var itemNumber = GetNullableDecimal(reader, "ItemNumber");
            var lineUid = GetNullableString(reader, "LineUID");
            var quantity = GetNullableDecimal(reader, "Quantity");
            var extendedSellAmount = GetNullableDecimal(reader, "Sell");
            decimal? unitSellAmount = quantity.HasValue && quantity.Value > 0 && extendedSellAmount.HasValue
                ? decimal.Round(extendedSellAmount.Value / quantity.Value, 4, MidpointRounding.AwayFromZero)
                : null;

            bomLines.Add(new BomLineCandidate
            {
                DbId = dbId,
                QuoteId = quoteId,
                ProjectErpId = GetNullableString(reader, "ProjectExternalId"),
                BomCrmId = BuildBomCrmId(dbId, quoteId),
                SourceBidId = dbId is null || quoteId is null ? null : $"{dbId}:{quoteId}",
                SourceProjectId = GetNullableString(reader, "ProjectId"),
                SourceLineId = BuildBomLineSourceId(dbId, quoteId, lineUid, itemNumber),
                ErpLineId = BuildBomLineErpId(lineUid, itemNumber),
                ItemNumber = itemNumber,
                LineUid = lineUid,
                ManufacturerErpId = GetNullableString(reader, "ManufacturerId"),
                Type = GetNullableString(reader, "Type"),
                ModelNumber = NormalizeProductText(GetNullableString(reader, "PartNumber")),
                Description = NormalizeProductText(GetNullableString(reader, "Description")),
                Quantity = quantity,
                ExtendedSellAmount = extendedSellAmount,
                UnitSellAmount = unitSellAmount,
                BookAmount = GetNullableDecimal(reader, "Book"),
                BaseAmount = GetNullableDecimal(reader, "Base"),
                OBaseAmount = GetNullableDecimal(reader, "OBase"),
                Level1Amount = GetNullableDecimal(reader, "Level1"),
                Level2Amount = GetNullableDecimal(reader, "Level2"),
                Level3Amount = GetNullableDecimal(reader, "Level3"),
                BidStatus = GetNullableString(reader, "BidStatus"),
                UpdateDate = GetNullableDateTime(reader, "UpdateDate")
            });
        }

        return bomLines;
    }

    private static IReadOnlyList<DestinationFieldCoverage> BuildOpportunityFieldCoverage(IReadOnlyList<OpportunityCandidate> opportunities)
    {
        var total = opportunities.Count;

        return
        [
            new DestinationFieldCoverage("project", "direct", "src.Bid.ProjectExternalId -> Parspec project erpId", total, opportunities.Count(opportunity => !string.IsNullOrWhiteSpace(opportunity.ProjectErpId)), "Every opportunity candidate is tied to a source project external id."),
            new DestinationFieldCoverage("title", "direct", "src.Bid.BidName fallback src.Project.ProjectName", total, opportunities.Count(opportunity => !string.IsNullOrWhiteSpace(opportunity.Title)), "Bid/package title is available for all current source rows."),
            new DestinationFieldCoverage("crmId", "derived", "src.Bid.DBID + QuoteId", total, opportunities.Count(opportunity => !string.IsNullOrWhiteSpace(opportunity.CrmId)), "Composite quote header key gives a stable opportunity crmId."),
            new DestinationFieldCoverage("estimatedValue", "direct", "src.Bid.Sell", total, opportunities.Count(opportunity => opportunity.EstimatedValue.HasValue), "Quote-header sell total is available from src.Bid."),
            new DestinationFieldCoverage("quoteDueDate", "direct", "src.Bid.BidDate", total, opportunities.Count(opportunity => opportunity.QuoteDueDate.HasValue), "Bid date is a strong first-pass quote due date candidate."),
            new DestinationFieldCoverage("submittalDueDate", "derived", "OASIS_MACSII.oasis.CHSC_QUOTE.EXPIRATIONDATE", total, opportunities.Count(opportunity => opportunity.SubmittalDueDate.HasValue), "Expiration date is being used as first-pass submittal due date by migration policy."),
            new DestinationFieldCoverage("quoter", "derived", "src.Bid.QuoteUserId -> AO user -> Parspec user", total, opportunities.Count(opportunity => !string.IsNullOrWhiteSpace(opportunity.QuoterAoUserId)), "Source-side quoter AO user id is available for most bids."),
            new DestinationFieldCoverage("pm", "derived", "src.Project.ProjectCoordinator -> AO user -> Parspec user", total, opportunities.Count(opportunity => !string.IsNullOrWhiteSpace(opportunity.ProjectManagerAoUserId)), "Project coordinator can seed the opportunity PM field when user mapping exists."),
            new DestinationFieldCoverage("stage", "derived", "src.Bid.BidStatus", total, opportunities.Count(opportunity => !string.IsNullOrWhiteSpace(opportunity.BidStatus)), "Stage will be translated from business-layer bid status."),
            new DestinationFieldCoverage("priority", "unresolved", "Intentionally deferred for first pass", total, 0, "Priority is being ignored for now by migration policy."),
            new DestinationFieldCoverage("scopes", "default", "First-pass migration default", total, total, "Scopes can stay empty in the first opportunity pass.")
        ];
    }

    private static IReadOnlyList<DestinationFieldCoverage> BuildBomFieldCoverage(IReadOnlyList<BomCandidate> boms)
    {
        var total = boms.Count;

        return
        [
            new DestinationFieldCoverage("opportunity", "direct", "src.QuoteItem.DBID + QuoteId -> src.Bid -> Parspec opportunity crmId", total, boms.Count(bom => !string.IsNullOrWhiteSpace(bom.ProjectErpId) && !string.IsNullOrWhiteSpace(bom.QuoteId)), "Each BOM candidate is grouped from quote items under a single quote header/opportunity."),
            new DestinationFieldCoverage("crmId", "derived", "src.QuoteItem.DBID + QuoteId", total, boms.Count(bom => !string.IsNullOrWhiteSpace(bom.CrmId)), "Composite quote key gives a stable BOM crmId candidate."),
            new DestinationFieldCoverage("name", "direct", "src.Bid.BidName fallback src.Project.ProjectName", total, boms.Count(bom => !string.IsNullOrWhiteSpace(bom.Name)), "BOM header can use the bid/package name, with project name as fallback."),
            new DestinationFieldCoverage("salesAgent", "derived", "src.Bid.QuoteUserId -> AO user -> Parspec user", total, boms.Count(bom => !string.IsNullOrWhiteSpace(bom.SalesAgentAoUserId)), "Quote owner can seed the BOM sales agent when the user mapping exists."),
            new DestinationFieldCoverage("primaryContact", "derived", "oasis.CHSC_QUOTECONTACT distributor rows, fallback oasis.CHSC_QUOTEDISTRIBUTORCONTACT, filtered through src.Account role = Distributor", total, boms.Count(bom => !string.IsNullOrWhiteSpace(bom.PrimaryContactCompanyErpId) || !string.IsNullOrWhiteSpace(bom.PrimaryContactSourceId)), "Primary BOM customer is restricted to distributor accounts only, with contact fallback where present."),
            new DestinationFieldCoverage("secondaryContact", "derived", "oasis.CHSC_QUOTECONTACT distributor rows, fallback oasis.CHSC_QUOTEDISTRIBUTORCONTACT, filtered through src.Account role = Distributor", total, boms.Count(bom => !string.IsNullOrWhiteSpace(bom.SecondaryContactCompanyErpId) || !string.IsNullOrWhiteSpace(bom.SecondaryContactSourceId)), "Secondary BOM customer is restricted to the next distinct distributor account, with contact fallback where present.")
        ];
    }

    private static IReadOnlyList<DestinationFieldCoverage> BuildBomLineFieldCoverage(IReadOnlyList<BomLineCandidate> bomLines)
    {
        var total = bomLines.Count;

        return
        [
            new DestinationFieldCoverage("bom", "derived", "src.QuoteItem.DBID + QuoteId -> BOM crmId", total, bomLines.Count(line => !string.IsNullOrWhiteSpace(line.BomCrmId)), "Each source line can be attached to a BOM header through the existing composite BOM crmId."),
            new DestinationFieldCoverage("erpLineId", "derived", "src.QuoteItem.LineUID fallback ItemNumber", total, bomLines.Count(line => !string.IsNullOrWhiteSpace(line.ErpLineId)), "LineUID is the best first-pass external line key; ItemNumber can backfill when LineUID is absent."),
            new DestinationFieldCoverage("modelNumber", "direct", "src.QuoteItem.PartNumber", total, bomLines.Count(line => !string.IsNullOrWhiteSpace(line.ModelNumber)), "Part number is the strongest candidate for Parspec model number."),
            new DestinationFieldCoverage("description", "direct", "src.QuoteItem.Description", total, bomLines.Count(line => !string.IsNullOrWhiteSpace(line.Description)), "Description is available for many lines, though some structural/grouping rows are blank."),
            new DestinationFieldCoverage("manufacturerErpId", "direct", "src.QuoteItem.ManufacturerId", total, bomLines.Count(line => !string.IsNullOrWhiteSpace(line.ManufacturerErpId)), "Manufacturer ERP id is already exposed by the business layer."),
            new DestinationFieldCoverage("quantity", "direct", "src.QuoteItem.Quantity", total, bomLines.Count(line => line.Quantity.HasValue), "Extended line quantity is already calculated in the business layer."),
            new DestinationFieldCoverage("unitSellPriceAmount", "derived", "src.QuoteItem.Sell / Quantity", total, bomLines.Count(line => line.UnitSellAmount.HasValue), "A first-pass unit sell price can be derived where quantity is non-zero."),
            new DestinationFieldCoverage("extendedSellPriceAmount", "direct", "src.QuoteItem.Sell", total, bomLines.Count(line => line.ExtendedSellAmount.HasValue), "Business-layer sell amount is the best available extended sell value."),
            new DestinationFieldCoverage("pricingPer", "default", "Migration policy default of 1", total, total, "Until Parspec line-write behavior is confirmed, pricing-per can default to 1."),
            new DestinationFieldCoverage("sellingUom", "default", "Migration policy default of EA", total, total, "The current business layer does not expose a distinct selling UOM, so first pass can default to EA."),
            new DestinationFieldCoverage("type", "direct", "src.QuoteItem.Type", total, bomLines.Count(line => !string.IsNullOrWhiteSpace(line.Type)), "Quote-item type codes are available and may help validate grouping or breakout behavior."),
            new DestinationFieldCoverage("productErpId", "unresolved", "No dedicated product/item master key surfaced yet", total, 0, "Part number may be usable later, but no confirmed Parspec product ERP mapping has been chosen yet."),
            new DestinationFieldCoverage("publicWriteEndpoint", "unresolved", "Parspec published schema does not currently expose a BOM-line create/update endpoint", total, 0, "We can prepare the payload contract now, but line creation still needs the confirmed destination endpoint.")
        ];
    }

    private static string? BuildBomCrmId(string? dbId, string? quoteId)
    {
        var normalizedDbId = NullIfWhiteSpace(dbId);
        var normalizedQuoteId = NullIfWhiteSpace(quoteId);
        return normalizedDbId is null || normalizedQuoteId is null
            ? null
            : $"{normalizedDbId}-BOM-{normalizedQuoteId}";
    }

    private static string? BuildBomLineSourceId(string? dbId, string? quoteId, string? lineUid, decimal? itemNumber)
    {
        var normalizedDbId = NullIfWhiteSpace(dbId);
        var normalizedQuoteId = NullIfWhiteSpace(quoteId);
        var normalizedLineUid = NullIfWhiteSpace(lineUid);

        if (normalizedDbId is null || normalizedQuoteId is null)
        {
            return null;
        }

        return normalizedLineUid is not null
            ? $"{normalizedDbId}:{normalizedQuoteId}:{normalizedLineUid}"
            : itemNumber.HasValue
                ? $"{normalizedDbId}:{normalizedQuoteId}:ITEM-{itemNumber.Value:0.##}"
                : null;
    }

    private static string? BuildBomLineErpId(string? lineUid, decimal? itemNumber)
    {
        var normalizedLineUid = NullIfWhiteSpace(lineUid);
        if (normalizedLineUid is not null)
        {
            return normalizedLineUid;
        }

        return itemNumber.HasValue ? itemNumber.Value.ToString("0.##") : null;
    }

    private static string? NormalizeProductText(string? value)
    {
        var normalized = NullIfWhiteSpace(value);
        return normalized?.Replace("\r", " ").Replace("\n", " ").Replace("\t", " ").Trim();
    }

    private static string? BuildSourceContactKey(string? contactDbId, string? contactId)
    {
        var normalizedDbId = NullIfWhiteSpace(contactDbId);
        var normalizedContactId = NullIfWhiteSpace(contactId);
        return normalizedDbId is null || normalizedContactId is null
            ? null
            : $"{normalizedDbId}:{normalizedContactId}";
    }

    private static async Task<List<ProjectCandidate>> LoadProjectCandidatesAsync(
        string businessConnectionString,
        IReadOnlyDictionary<string, int> locationMappings)
    {
        const string sql = """
SELECT
    DBID,
    ProjectName,
    ExternalId,
    OldProjectId,
    QuoteNumber,
    QuoteDistributorId,
    CustomerContactId,
    ParentExternalId,
    ProjectRank,
    BidDate,
    CurrentBidDate,
    QuoteStatus,
    LocationCity,
    LocationState,
    CreateDate,
    UpdateDate,
    ProjectOwner,
    Quoter,
    WorkGroup,
    ShowOnBidBoard,
    Valuation,
    Sell,
    QuoteLineCount,
    ProjectCoordinator,
    ProjectStage,
    QuoteType,
    Source,
    PhaseName,
    ProjectPOs,
    Ordered,
    Released,
    OrderedDate,
    WinningDistributorId,
    WinningCustomerId,
    WinningContractorId,
    Followers,
    Engineer,
    Architect,
    Earnings,
    LockedBy,
    ManufacturerBTS,
    BuySellBTS,
    BuySellBTI,
    SquareFootage,
    VerticalMarket
FROM SRC.Project
ORDER BY UpdateDate DESC, ProjectName, ExternalId;
""";

        var projects = new List<ProjectCandidate>();
        await using var connection = new SqlConnection(businessConnectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            var workGroup = GetNullableString(reader, "WorkGroup");
            int? locationId = null;
            if (!string.IsNullOrWhiteSpace(workGroup) && locationMappings.TryGetValue(workGroup, out var configuredLocationId))
            {
                locationId = configuredLocationId;
            }

            var crmId = GetNullableString(reader, "OldProjectId");
            projects.Add(new ProjectCandidate
            {
                DbId = GetNullableString(reader, "DBID"),
                Name = GetNullableString(reader, "ProjectName"),
                ErpId = GetNullableString(reader, "ExternalId"),
                CrmId = crmId,
                QuoteNumber = GetNullableString(reader, "QuoteNumber"),
                QuoteDistributorId = GetNullableString(reader, "QuoteDistributorId"),
                CustomerContactId = GetNullableString(reader, "CustomerContactId"),
                ParentExternalId = GetNullableString(reader, "ParentExternalId"),
                ProjectRank = GetNullableString(reader, "ProjectRank"),
                BidDate = GetNullableDateTime(reader, "BidDate"),
                CurrentBidDate = GetNullableDateTime(reader, "CurrentBidDate"),
                QuoteStatus = GetNullableString(reader, "QuoteStatus"),
                LocationCity = GetNullableString(reader, "LocationCity"),
                LocationState = NormalizeRegionCode(GetNullableString(reader, "LocationState")),
                CreateDate = GetNullableDateTime(reader, "CreateDate"),
                UpdateDate = GetNullableDateTime(reader, "UpdateDate"),
                OwnerUserId = GetNullableString(reader, "ProjectOwner"),
                QuoterUserId = GetNullableString(reader, "Quoter"),
                WorkGroup = workGroup,
                LocationId = locationId,
                ShowOnBidBoard = GetNullableInt(reader, "ShowOnBidBoard") == 1,
                Valuation = GetNullableDecimal(reader, "Valuation"),
                Sell = GetNullableDecimal(reader, "Sell"),
                QuoteLineCount = GetNullableDecimal(reader, "QuoteLineCount"),
                ProjectCoordinatorUserId = GetNullableString(reader, "ProjectCoordinator"),
                ProjectStage = GetNullableString(reader, "ProjectStage"),
                QuoteType = GetNullableString(reader, "QuoteType"),
                PhaseName = GetNullableString(reader, "PhaseName"),
                ProjectPOs = GetNullableString(reader, "ProjectPOs"),
                Ordered = GetNullableDecimal(reader, "Ordered"),
                Released = GetNullableDecimal(reader, "Released"),
                OrderedDate = GetNullableDateTime(reader, "OrderedDate"),
                WinningDistributorId = GetNullableString(reader, "WinningDistributorId"),
                WinningCustomerId = GetNullableString(reader, "WinningCustomerId"),
                WinningContractorId = GetNullableString(reader, "WinningCOntractorId"),
                Followers = GetNullableString(reader, "Followers"),
                EngineerCompanyId = GetNullableString(reader, "Engineer"),
                ArchitectCompanyId = GetNullableString(reader, "Architect"),
                Earnings = GetNullableDecimal(reader, "Earnings"),
                LockedBy = GetNullableString(reader, "LockedBy"),
                ManufacturerBts = GetNullableInt(reader, "ManufacturerBTS") == 1,
                BuySellBts = GetNullableInt(reader, "BuySellBTS") == 1,
                BuySellBti = GetNullableInt(reader, "BuySellBTI") == 1,
                SquareFootage = GetNullableInt(reader, "SquareFootage"),
                MarketVertical = GetNullableString(reader, "VerticalMarket")
            });
        }

        return projects;
    }

    private static IReadOnlyList<DestinationFieldCoverage> BuildProjectFieldCoverage(
        IReadOnlyList<ProjectCandidate> projects,
        IReadOnlySet<string> stakeholderProjectIds)
    {
        var total = projects.Count;

        return
        [
            new DestinationFieldCoverage("name", "direct", "src.Project.ProjectName", total, projects.Count(project => !string.IsNullOrWhiteSpace(project.Name)), "Project name is available for all current source project rows."),
            new DestinationFieldCoverage("location", "derived", "src.Project.WorkGroup -> configured Parspec location id", total, projects.Count(project => project.LocationId.HasValue), "Parspec v2 projects require a location id; current readiness depends on configured workgroup mappings."),
            new DestinationFieldCoverage("erpId", "direct", "src.Project.ExternalId", total, projects.Count(project => !string.IsNullOrWhiteSpace(project.ErpId)), "Business-layer project external id is available for all source rows."),
            new DestinationFieldCoverage("crmId", "derived", "src.Project.OldProjectId", total, projects.Count(project => !string.IsNullOrWhiteSpace(project.CrmId)), "Legacy project id can be carried as a first-pass CRM id candidate."),
            new DestinationFieldCoverage("projectCode", "direct", "src.Project.QuoteNumber", total, projects.Count(project => !string.IsNullOrWhiteSpace(project.QuoteNumber)), "Quote number can seed a first-pass project code."),
            new DestinationFieldCoverage("marketVertical", "direct", "src.Project.VerticalMarket", total, projects.Count(project => !string.IsNullOrWhiteSpace(project.MarketVertical)), "Market vertical is partially available from source."),
            new DestinationFieldCoverage("address", "direct", "src.Project.LocationCity / LocationState", total, projects.Count(project => !string.IsNullOrWhiteSpace(project.LocationCity) || !string.IsNullOrWhiteSpace(project.LocationState)), "Project geography is available at city/state level; no street/postal source identified in the business layer."),
            new DestinationFieldCoverage("owner", "derived", "src.Project.ProjectOwner", total, projects.Count(project => !string.IsNullOrWhiteSpace(project.OwnerUserId)), "Project owner AO user id is available for many rows, but still needs destination-user mapping policy."),
            new DestinationFieldCoverage("projectStakeholders", "derived", "src.ProjectAccount limited to the selected AO.Bid for the current project quote", total, projects.Count(project => !string.IsNullOrWhiteSpace(project.ErpId) && stakeholderProjectIds.Contains(project.ErpId)), "Stakeholders are sourced from ProjectAccount rows associated with the project's selected business-layer bid."),
            new DestinationFieldCoverage("constructionScope", "unresolved", "No source selected yet", total, 0, "No first-pass construction scope source identified yet."),
            new DestinationFieldCoverage("squareFootage", "direct", "src.Project.SquareFootage <- oasis.CHSC_PROJECTBIDPACKAGE.SquareFootage", total, projects.Count(project => project.SquareFootage.HasValue && project.SquareFootage.Value > 0), "Square footage is now sourced from the Oasis project bid package when present, though current coverage is sparse."),
            new DestinationFieldCoverage("priority", "unresolved", "No source selected yet", total, 0, "Parspec project priority has no current source mapping."),
            new DestinationFieldCoverage("projectStage", "direct", "src.Project.ProjectStage", total, projects.Count(project => !string.IsNullOrWhiteSpace(project.ProjectStage)), "Project stage is already derived in the business layer, though Parspec enum compatibility still needs validation."),
            new DestinationFieldCoverage("estimatedValue", "derived", "src.Project.Valuation", total, projects.Count(project => project.Valuation.HasValue), "Source valuation exists and can support project value decisions even if the exact Parspec field surface differs by API version.")
        ];
    }

    private static async Task<ProjectMigrationContext> BuildProjectMigrationContextAsync(ParspecMigratorConfig config)
    {
        var existingProjects = await LoadAllParspecProjectsAsync(config);
        var existingCompanies = await LoadAllParspecCompaniesAsync(config);
        var existingContacts = await LoadAllParspecContactsAsync(config);
        var stakeholderCandidates = await LoadProjectStakeholderCandidatesAsync(config.BusinessConnectionString);

        return new ProjectMigrationContext
        {
            ExistingProjectsByErpId = existingProjects
                .Where(project => !string.IsNullOrWhiteSpace(project.ErpId))
                .GroupBy(project => project.ErpId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingProjectsByCrmId = existingProjects
                .Where(project => !string.IsNullOrWhiteSpace(project.CrmId))
                .GroupBy(project => project.CrmId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingProjectsByNaturalKey = existingProjects
                .GroupBy(BuildProjectNaturalKey, StringComparer.OrdinalIgnoreCase)
                .Where(group => !string.IsNullOrWhiteSpace(group.Key))
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingProjectsByLooseNaturalKey = existingProjects
                .GroupBy(project => BuildLooseProjectNaturalKey(project.Location, project.Name), StringComparer.OrdinalIgnoreCase)
                .Where(group => !string.IsNullOrWhiteSpace(group.Key) && group.Count() == 1)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingCompaniesByErpId = existingCompanies
                .Where(company => !string.IsNullOrWhiteSpace(company.ErpId))
                .GroupBy(company => company.ErpId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingCompaniesByCrmId = existingCompanies
                .Where(company => !string.IsNullOrWhiteSpace(company.CrmId))
                .GroupBy(company => company.CrmId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingContactsByCrmId = existingContacts
                .Where(contact => !string.IsNullOrWhiteSpace(contact.CrmId))
                .GroupBy(contact => contact.CrmId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            StakeholdersByProjectErpId = stakeholderCandidates
                .Where(candidate => !string.IsNullOrWhiteSpace(candidate.ProjectErpId))
                .GroupBy(candidate => candidate.ProjectErpId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => (IReadOnlyList<ProjectStakeholderCandidate>)group.ToList(), StringComparer.OrdinalIgnoreCase)
        };
    }

    private static async Task<List<ProjectStakeholderCandidate>> LoadProjectStakeholderCandidatesAsync(string businessConnectionString)
    {
        const string sql = """
WITH RankedBid AS (
    SELECT
        p.ExternalId AS ProjectErpId,
        p.QuoteNumber,
        bid.Id AS AOBidId,
        bid.Cst_ProjectId__c AS AOProjectId,
        bid.Cst_QuoteId__c AS QuoteId,
        ROW_NUMBER() OVER (
            PARTITION BY p.ExternalId
            ORDER BY
                CASE WHEN TRY_CONVERT(varchar(50), bid.Cst_QuoteId__c) = p.QuoteNumber THEN 0 ELSE 1 END,
                bid.Cst_BidDate__c DESC,
                bid.Cst_QuoteId__c DESC,
                bid.Id DESC
        ) AS RowNum
    FROM src.Project p
    INNER JOIN AO.Bid bid
        ON bid.Cst_ProjectId__c = (
            SELECT TOP 1 sb.ProjectId
            FROM src.Bid sb
            WHERE sb.ProjectExternalId = p.ExternalId
            ORDER BY
                CASE WHEN CAST(sb.QuoteId AS varchar(50)) = p.QuoteNumber THEN 0 ELSE 1 END,
                sb.BidDate DESC,
                sb.QuoteId DESC
        )
    WHERE ISNULL(p.ExternalId, '') <> ''
),
SelectedBid AS (
    SELECT ProjectErpId, AOBidId, AOProjectId, QuoteId
    FROM RankedBid
    WHERE RowNum = 1
)
SELECT
    sb.ProjectErpId,
    pa.ProjectId AS AOProjectId,
    pa.BidId AS AOBidId,
    pa.AccountId AS AccountCrmId,
    aoAccount.Cst_External_Id__c AS AccountErpId,
    pa.ContactId AS ContactCrmId,
    aoContact.ExternalId__c AS ContactExternalId,
    pa.AccountCategory,
    pa.ActiveStatus,
    pa.Role
FROM SelectedBid sb
INNER JOIN src.ProjectAccount pa
    ON pa.ProjectId = sb.AOProjectId
   AND pa.BidId = sb.AOBidId
LEFT JOIN AO.Account aoAccount
    ON aoAccount.Id = pa.AccountId
LEFT JOIN AO.Contact aoContact
    ON aoContact.Id = pa.ContactId
WHERE pa.ActiveStatus IN ('Active', 'Winner')
ORDER BY sb.ProjectErpId, pa.AccountCategory, pa.Role, pa.AccountId, pa.ContactId;
""";

        var stakeholders = new List<ProjectStakeholderCandidate>();
        await using var connection = new SqlConnection(businessConnectionString);
        await connection.OpenAsync();
        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            stakeholders.Add(new ProjectStakeholderCandidate
            {
                ProjectErpId = GetNullableString(reader, "ProjectErpId"),
                AOProjectId = GetNullableString(reader, "AOProjectId"),
                AOBidId = GetNullableString(reader, "AOBidId"),
                AccountCrmId = GetNullableString(reader, "AccountCrmId"),
                AccountErpId = GetNullableString(reader, "AccountErpId"),
                ContactCrmId = GetNullableString(reader, "ContactCrmId"),
                ContactExternalId = GetNullableString(reader, "ContactExternalId"),
                AccountCategory = GetNullableString(reader, "AccountCategory"),
                ActiveStatus = GetNullableString(reader, "ActiveStatus"),
                Role = GetNullableString(reader, "Role")
            });
        }

        return stakeholders;
    }

    private static async Task<List<ParspecProject>> LoadAllParspecProjectsAsync(ParspecMigratorConfig config)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var projects = new List<ParspecProject>();
        var start = 0;
        const int pageSize = 200;

        while (true)
        {
            using var response = await client.GetAsync($"v2/projects?start={start}&limit={pageSize}");
            var body = await response.Content.ReadAsStringAsync();
            response.EnsureSuccessStatusCode();

            var payload = JsonSerializer.Deserialize<ParspecProjectListResponse>(body, ApiJsonOptions)
                ?? new ParspecProjectListResponse();

            projects.AddRange(payload.Results);

            if (payload.Results.Count < pageSize)
            {
                break;
            }

            start += pageSize;
        }

        return projects;
    }

    private static async Task<OpportunityMigrationContext> BuildOpportunityMigrationContextAsync(
        ParspecMigratorConfig config,
        IReadOnlyDictionary<string, int> locationMap)
    {
        var existingProjects = await LoadAllParspecProjectsAsync(config);
        var sourceUsers = await LoadUserCandidatesAsync(config.BusinessConnectionString, locationMap);
        var parspecUsers = await LoadParspecUsersAsync(config);

        return new OpportunityMigrationContext
        {
            ExistingProjectsByErpId = existingProjects
                .Where(project => !string.IsNullOrWhiteSpace(project.ErpId))
                .GroupBy(project => project.ErpId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingOpportunitiesByProjectId = new Dictionary<int, Dictionary<string, ParspecOpportunity>>( ),
            ExistingOpportunitiesByProjectIdAndTitle = new Dictionary<int, Dictionary<string, ParspecOpportunity>>(),
            SourceUsers = sourceUsers,
            ParspecUsers = parspecUsers
        };
    }

    private static async Task<OpportunityMigrationExecutionResult> CreateOrUpdateOpportunityAsync(
        ParspecMigratorConfig config,
        OpportunityCandidate candidate,
        OpportunityMigrationContext context)
    {
        if (string.IsNullOrWhiteSpace(candidate.ProjectErpId)
            || !context.ExistingProjectsByErpId.TryGetValue(candidate.ProjectErpId, out var project))
        {
            return new OpportunityMigrationExecutionResult
            {
                SourceProjectErpId = candidate.ProjectErpId,
                SourceQuoteId = candidate.QuoteId,
                SourceTitle = candidate.Title,
                Status = "failed",
                Message = $"No Parspec project found for source project erpId {candidate.ProjectErpId ?? "(blank)"}."
            };
        }

        await EnsureProjectOpportunitiesLoadedAsync(config, project.Id, context);

        var payload = BuildOpportunityPayload(candidate, context);
        var existingOpportunity = FindExistingOpportunity(candidate, project.Id, payload, context);
        if (existingOpportunity is not null)
        {
            return await PatchParspecOpportunityAsync(config, project.Id, existingOpportunity.Id, candidate, payload);
        }

        var createResult = await CreateParspecOpportunityAsync(config, project.Id, candidate, payload);
        if (createResult.Status == "created" && createResult.ParspecOpportunityId.HasValue)
        {
            RegisterOpportunityInContext(project.Id, new ParspecOpportunity
            {
                Id = createResult.ParspecOpportunityId.Value,
                CrmId = payload.CrmId,
                Title = payload.Title
            }, context);
        }

        return createResult;
    }

    private static async Task EnsureProjectOpportunitiesLoadedAsync(
        ParspecMigratorConfig config,
        int projectId,
        OpportunityMigrationContext context)
    {
        if (context.ExistingOpportunitiesByProjectId.ContainsKey(projectId))
        {
            return;
        }

        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var byCrmId = new Dictionary<string, ParspecOpportunity>(StringComparer.OrdinalIgnoreCase);
        var byTitle = new Dictionary<string, ParspecOpportunity>(StringComparer.OrdinalIgnoreCase);
        var start = 0;
        const int pageSize = 200;

        while (true)
        {
            using var response = await client.GetAsync($"v2/projects/{projectId}/opportunities?start={start}&limit={pageSize}");
            var body = await response.Content.ReadAsStringAsync();
            response.EnsureSuccessStatusCode();

            var payload = JsonSerializer.Deserialize<ParspecOpportunityListResponse>(body, ApiJsonOptions)
                ?? new ParspecOpportunityListResponse();

            foreach (var opportunity in payload.Results)
            {
                if (!string.IsNullOrWhiteSpace(opportunity.CrmId))
                {
                    byCrmId[opportunity.CrmId] = opportunity;
                }

                var titleKey = NullIfWhiteSpace(opportunity.Title);
                if (!string.IsNullOrWhiteSpace(titleKey) && !byTitle.ContainsKey(titleKey))
                {
                    byTitle[titleKey] = opportunity;
                }
            }

            if (payload.Results.Count < pageSize)
            {
                break;
            }

            start += pageSize;
        }

        context.ExistingOpportunitiesByProjectId[projectId] = byCrmId;
        context.ExistingOpportunitiesByProjectIdAndTitle[projectId] = byTitle;
    }

    private static async Task EnsureProjectOpportunitiesLoadedAsync(
        ParspecMigratorConfig config,
        int projectId,
        BomMigrationContext context)
    {
        if (context.ExistingOpportunitiesByProjectId.ContainsKey(projectId))
        {
            return;
        }

        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var byCrmId = new Dictionary<string, ParspecOpportunity>(StringComparer.OrdinalIgnoreCase);
        var byTitle = new Dictionary<string, ParspecOpportunity>(StringComparer.OrdinalIgnoreCase);
        var start = 0;
        const int pageSize = 200;

        while (true)
        {
            using var response = await client.GetAsync($"v2/projects/{projectId}/opportunities?start={start}&limit={pageSize}");
            var body = await response.Content.ReadAsStringAsync();
            response.EnsureSuccessStatusCode();

            var payload = JsonSerializer.Deserialize<ParspecOpportunityListResponse>(body, ApiJsonOptions)
                ?? new ParspecOpportunityListResponse();

            foreach (var opportunity in payload.Results)
            {
                if (!string.IsNullOrWhiteSpace(opportunity.CrmId))
                {
                    byCrmId[opportunity.CrmId] = opportunity;
                }

                var titleKey = NullIfWhiteSpace(opportunity.Title);
                if (!string.IsNullOrWhiteSpace(titleKey) && !byTitle.ContainsKey(titleKey))
                {
                    byTitle[titleKey] = opportunity;
                }
            }

            if (payload.Results.Count < pageSize)
            {
                break;
            }

            start += pageSize;
        }

        context.ExistingOpportunitiesByProjectId[projectId] = byCrmId;
        context.ExistingOpportunitiesByProjectIdAndTitle[projectId] = byTitle;
    }

    private static async Task EnsureOpportunityBomsLoadedAsync(
        ParspecMigratorConfig config,
        int projectId,
        int opportunityId,
        BomMigrationContext context)
    {
        if (context.ExistingBomsByOpportunityId.TryGetValue(opportunityId, out _))
        {
            return;
        }

        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var byCrmId = new Dictionary<string, ParspecBom>(StringComparer.OrdinalIgnoreCase);
        var byName = new Dictionary<string, ParspecBom>(StringComparer.OrdinalIgnoreCase);
        var start = 0;
        const int pageSize = 200;

        while (true)
        {
            using var response = await client.GetAsync($"v2/projects/{projectId}/opportunities/{opportunityId}/boms?start={start}&limit={pageSize}");
            var body = await response.Content.ReadAsStringAsync();
            response.EnsureSuccessStatusCode();

            var payload = JsonSerializer.Deserialize<ParspecBomListResponse>(body, ApiJsonOptions)
                ?? new ParspecBomListResponse();

            foreach (var bom in payload.Results)
            {
                if (!string.IsNullOrWhiteSpace(bom.CrmId))
                {
                    byCrmId[bom.CrmId] = bom;
                }

                var nameKey = NullIfWhiteSpace(bom.Name);
                if (!string.IsNullOrWhiteSpace(nameKey) && !byName.ContainsKey(nameKey))
                {
                    byName[nameKey] = bom;
                }
            }

            if (payload.Results.Count < pageSize)
            {
                break;
            }

            start += pageSize;
        }

        context.ExistingBomsByOpportunityId[opportunityId] = byCrmId;
        context.ExistingBomsByOpportunityIdAndName[opportunityId] = byName;
    }

    private static ParspecBom? FindExistingBom(
        int projectId,
        int opportunityId,
        BomV2Payload payload,
        BomMigrationContext context)
    {
        if (!string.IsNullOrWhiteSpace(payload.CrmId)
            && context.ExistingBomsByOpportunityId.TryGetValue(opportunityId, out var byCrmId)
            && byCrmId.TryGetValue(payload.CrmId, out var bomByCrmId))
        {
            return bomByCrmId;
        }

        if (!string.IsNullOrWhiteSpace(payload.Name)
            && context.ExistingBomsByOpportunityIdAndName.TryGetValue(opportunityId, out var byName)
            && byName.TryGetValue(payload.Name, out var bomByName))
        {
            return bomByName;
        }

        return null;
    }

    private static void RegisterBomInContext(
        int projectId,
        int opportunityId,
        ParspecBom bom,
        BomMigrationContext context)
    {
        if (!context.ExistingBomsByOpportunityId.TryGetValue(opportunityId, out var byCrmId))
        {
            byCrmId = new Dictionary<string, ParspecBom>(StringComparer.OrdinalIgnoreCase);
            context.ExistingBomsByOpportunityId[opportunityId] = byCrmId;
        }

        if (!context.ExistingBomsByOpportunityIdAndName.TryGetValue(opportunityId, out var byName))
        {
            byName = new Dictionary<string, ParspecBom>(StringComparer.OrdinalIgnoreCase);
            context.ExistingBomsByOpportunityIdAndName[opportunityId] = byName;
        }

        if (!string.IsNullOrWhiteSpace(bom.CrmId))
        {
            byCrmId[bom.CrmId] = bom;
        }

        if (!string.IsNullOrWhiteSpace(bom.Name))
        {
            byName[bom.Name] = bom;
        }
    }

    private static async Task<BomMigrationExecutionResult> CreateParspecBomAsync(
        ParspecMigratorConfig config,
        int projectId,
        int opportunityId,
        BomCandidate candidate,
        BomV2Payload payload)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Post, $"v2/projects/{projectId}/opportunities/{opportunityId}/boms")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"BOM create failed for {candidate.ProjectErpId} / Quote {candidate.QuoteId} ({candidate.Name}): HTTP {(int)response.StatusCode} {response.StatusCode}");
            Console.WriteLine(responseBody);

            return new BomMigrationExecutionResult
            {
                SourceProjectErpId = candidate.ProjectErpId,
                SourceQuoteId = candidate.QuoteId,
                SourceName = candidate.Name,
                Status = "failed",
                Message = responseBody
            };
        }

        var createdBom = JsonSerializer.Deserialize<ParspecBom>(responseBody, ApiJsonOptions);

        return new BomMigrationExecutionResult
        {
            SourceProjectErpId = candidate.ProjectErpId,
            SourceQuoteId = candidate.QuoteId,
            SourceName = candidate.Name,
            Status = "created",
            ParspecBomId = createdBom?.Id,
            Message = responseBody
        };
    }

    private static async Task<BomMigrationExecutionResult> PatchParspecBomAsync(
        ParspecMigratorConfig config,
        int projectId,
        int opportunityId,
        int bomId,
        BomCandidate candidate,
        BomV2Payload payload)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Patch, $"v2/projects/{projectId}/opportunities/{opportunityId}/boms/{bomId}")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"BOM update failed for {candidate.ProjectErpId} / Quote {candidate.QuoteId} ({candidate.Name}): HTTP {(int)response.StatusCode} {response.StatusCode}");
            Console.WriteLine(responseBody);

            return new BomMigrationExecutionResult
            {
                SourceProjectErpId = candidate.ProjectErpId,
                SourceQuoteId = candidate.QuoteId,
                SourceName = candidate.Name,
                Status = "failed",
                Message = responseBody
            };
        }

        return new BomMigrationExecutionResult
        {
            SourceProjectErpId = candidate.ProjectErpId,
            SourceQuoteId = candidate.QuoteId,
            SourceName = candidate.Name,
            Status = "updated-existing",
            ParspecBomId = bomId,
            Message = responseBody
        };
    }

    private static OpportunityV2Payload BuildOpportunityPayload(
        OpportunityCandidate candidate,
        OpportunityMigrationContext context)
    {
        return new OpportunityV2Payload
        {
            CrmId = candidate.CrmId ?? string.Empty,
            EstimatedValue = ToNullableCents(candidate.EstimatedValue),
            Pm = ResolveParspecUserId(candidate.ProjectManagerAoUserId, context.SourceUsers, context.ParspecUsers),
            PmPerScope = false,
            QuoteDueDate = FormatDate(candidate.QuoteDueDate),
            Quoter = ResolveParspecUserId(candidate.QuoterAoUserId, context.SourceUsers, context.ParspecUsers),
            QuoterPerScope = false,
            Scopes = Array.Empty<object>(),
            Stage = TranslateOpportunityStage(candidate.BidStatus),
            SubmittalDueDate = FormatDate(candidate.SubmittalDueDate),
            Title = candidate.Title ?? string.Empty
        };
    }

    private static ParspecOpportunity? FindExistingOpportunity(
        OpportunityCandidate candidate,
        int projectId,
        OpportunityV2Payload payload,
        OpportunityMigrationContext context)
    {
        if (!string.IsNullOrWhiteSpace(payload.CrmId)
            && context.ExistingOpportunitiesByProjectId.TryGetValue(projectId, out var byCrmId)
            && byCrmId.TryGetValue(payload.CrmId, out var opportunityByCrmId))
        {
            return opportunityByCrmId;
        }

        if (!string.IsNullOrWhiteSpace(payload.Title)
            && context.ExistingOpportunitiesByProjectIdAndTitle.TryGetValue(projectId, out var byTitle)
            && byTitle.TryGetValue(payload.Title, out var opportunityByTitle))
        {
            return opportunityByTitle;
        }

        return null;
    }

    private static void RegisterOpportunityInContext(
        int projectId,
        ParspecOpportunity opportunity,
        OpportunityMigrationContext context)
    {
        if (!context.ExistingOpportunitiesByProjectId.TryGetValue(projectId, out var byCrmId))
        {
            byCrmId = new Dictionary<string, ParspecOpportunity>(StringComparer.OrdinalIgnoreCase);
            context.ExistingOpportunitiesByProjectId[projectId] = byCrmId;
        }

        if (!context.ExistingOpportunitiesByProjectIdAndTitle.TryGetValue(projectId, out var byTitle))
        {
            byTitle = new Dictionary<string, ParspecOpportunity>(StringComparer.OrdinalIgnoreCase);
            context.ExistingOpportunitiesByProjectIdAndTitle[projectId] = byTitle;
        }

        if (!string.IsNullOrWhiteSpace(opportunity.CrmId))
        {
            byCrmId[opportunity.CrmId] = opportunity;
        }

        if (!string.IsNullOrWhiteSpace(opportunity.Title))
        {
            byTitle[opportunity.Title] = opportunity;
        }
    }

    private static async Task<OpportunityMigrationExecutionResult> CreateParspecOpportunityAsync(
        ParspecMigratorConfig config,
        int projectId,
        OpportunityCandidate candidate,
        OpportunityV2Payload payload)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Post, $"v2/projects/{projectId}/opportunities")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"Opportunity create failed for {candidate.ProjectErpId} / Quote {candidate.QuoteId} ({candidate.Title}): HTTP {(int)response.StatusCode} {response.StatusCode}");
            Console.WriteLine(responseBody);

            return new OpportunityMigrationExecutionResult
            {
                SourceProjectErpId = candidate.ProjectErpId,
                SourceQuoteId = candidate.QuoteId,
                SourceTitle = candidate.Title,
                Status = "failed",
                Message = responseBody
            };
        }

        var createdOpportunity = JsonSerializer.Deserialize<ParspecOpportunity>(responseBody, ApiJsonOptions);

        return new OpportunityMigrationExecutionResult
        {
            SourceProjectErpId = candidate.ProjectErpId,
            SourceQuoteId = candidate.QuoteId,
            SourceTitle = candidate.Title,
            Status = "created",
            ParspecOpportunityId = createdOpportunity?.Id,
            Message = responseBody
        };
    }

    private static async Task<OpportunityMigrationExecutionResult> PatchParspecOpportunityAsync(
        ParspecMigratorConfig config,
        int projectId,
        int opportunityId,
        OpportunityCandidate candidate,
        OpportunityV2Payload payload)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Patch, $"v2/projects/{projectId}/opportunities/{opportunityId}")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"Opportunity update failed for {candidate.ProjectErpId} / Quote {candidate.QuoteId} ({candidate.Title}): HTTP {(int)response.StatusCode} {response.StatusCode}");
            Console.WriteLine(responseBody);

            return new OpportunityMigrationExecutionResult
            {
                SourceProjectErpId = candidate.ProjectErpId,
                SourceQuoteId = candidate.QuoteId,
                SourceTitle = candidate.Title,
                Status = "failed",
                Message = responseBody
            };
        }

        return new OpportunityMigrationExecutionResult
        {
            SourceProjectErpId = candidate.ProjectErpId,
            SourceQuoteId = candidate.QuoteId,
            SourceTitle = candidate.Title,
            Status = "updated-existing",
            ParspecOpportunityId = opportunityId,
            Message = responseBody
        };
    }

    private static int? ResolveParspecUserId(
        string? aoUserId,
        IReadOnlyList<UserCandidate> sourceUsers,
        IReadOnlyList<ParspecUser> parspecUsers)
    {
        if (string.IsNullOrWhiteSpace(aoUserId))
        {
            return null;
        }

        var sourceUser = sourceUsers.FirstOrDefault(user =>
            string.Equals(user.AoUserId, aoUserId, StringComparison.OrdinalIgnoreCase));

        if (sourceUser is null || string.IsNullOrWhiteSpace(sourceUser.OasisUserId))
        {
            return null;
        }

        var parspecUser = parspecUsers.FirstOrDefault(user =>
            string.Equals(user.ErpId, sourceUser.OasisUserId, StringComparison.OrdinalIgnoreCase));

        return parspecUser?.Id;
    }

    private static string? TranslateOpportunityStage(string? bidStatus)
    {
        return NullIfWhiteSpace(bidStatus) switch
        {
            "Prebid/Design" => "Specification",
            "(new)" => "Specification",
            "Budget" => "Specification",
            "Spec Build" => "Specification",
            "Quoted" => "Quoting",
            "Submitted" => "Quote Sent",
            "Order pending" => "Quote Sent",
            "Buy" => "Quoting",
            "Ordered" => "Closed Won",
            "Closed" => "Closed Won",
            "Lost" => "Closed Lost",
            "Abandoned" => "Closed Lost",
            "Cancelled" => "Closed Lost",
            "No Quote" => "No Bid",
            _ => "On Hold"
        };
    }

    private static string? BuildOpportunityCrmId(string? dbId, string? quoteId)
    {
        var normalizedDbId = NullIfWhiteSpace(dbId);
        var normalizedQuoteId = NullIfWhiteSpace(quoteId);
        return normalizedDbId is null || normalizedQuoteId is null
            ? null
            : $"{normalizedDbId}-{normalizedQuoteId}";
    }

    private static string? FormatDate(DateTime? value) =>
        value?.ToString("yyyy-MM-dd");

    private static async Task<ProjectMigrationExecutionResult> CreateOrUpdateProjectAsync(
        ParspecMigratorConfig config,
        ProjectCandidate candidate,
        ProjectMigrationContext context)
    {
        if (!candidate.LocationId.HasValue)
        {
            return new ProjectMigrationExecutionResult
            {
                SourceErpId = candidate.ErpId,
                SourceName = candidate.Name,
                Status = "failed",
                Message = $"No Parspec location mapping found for workgroup {candidate.WorkGroup ?? "(blank)"}."
            };
        }

        var payload = BuildProjectPayload(candidate, context);
        var existingProject = FindExistingParspecProject(candidate, payload, context);
        if (existingProject is not null)
        {
            var updateResult = await PatchParspecProjectAsync(config, existingProject.Id, candidate, payload);
            if (updateResult.Status == "updated-existing")
            {
                var updated = new ParspecProject
                {
                    Id = existingProject.Id,
                    ErpId = payload.ErpId,
                    CrmId = payload.CrmId,
                    Name = payload.Name,
                    Location = payload.Location
                };

                if (!string.IsNullOrWhiteSpace(updated.ErpId))
                {
                    context.ExistingProjectsByErpId[updated.ErpId] = updated;
                }

                if (!string.IsNullOrWhiteSpace(updated.CrmId))
                {
                    context.ExistingProjectsByCrmId[updated.CrmId] = updated;
                }

                var naturalKey = BuildProjectNaturalKey(updated);
                if (!string.IsNullOrWhiteSpace(naturalKey))
                {
                    context.ExistingProjectsByNaturalKey[naturalKey] = updated;
                }

                var looseNaturalKey = BuildLooseProjectNaturalKey(updated.Location, updated.Name);
                if (!string.IsNullOrWhiteSpace(looseNaturalKey))
                {
                    context.ExistingProjectsByLooseNaturalKey[looseNaturalKey] = updated;
                }
            }

            return await EnrichProjectViaV1Async(config, existingProject.Id, candidate, updateResult);
        }

        var createResult = await CreateParspecProjectAsync(config, candidate, payload);
        if (createResult.Status != "created" || createResult.ParspecProjectId is null)
        {
            return createResult;
        }

        var createdProject = new ParspecProject
        {
            Id = createResult.ParspecProjectId.Value,
            ErpId = payload.ErpId,
            CrmId = payload.CrmId,
            Name = payload.Name,
            Location = payload.Location
        };

        if (!string.IsNullOrWhiteSpace(createdProject.ErpId))
        {
            context.ExistingProjectsByErpId[createdProject.ErpId] = createdProject;
        }

        if (!string.IsNullOrWhiteSpace(createdProject.CrmId))
        {
            context.ExistingProjectsByCrmId[createdProject.CrmId] = createdProject;
        }

        var createdNaturalKey = BuildProjectNaturalKey(createdProject);
        if (!string.IsNullOrWhiteSpace(createdNaturalKey))
        {
            context.ExistingProjectsByNaturalKey[createdNaturalKey] = createdProject;
        }

        var createdLooseNaturalKey = BuildLooseProjectNaturalKey(createdProject.Location, createdProject.Name);
        if (!string.IsNullOrWhiteSpace(createdLooseNaturalKey))
        {
            context.ExistingProjectsByLooseNaturalKey[createdLooseNaturalKey] = createdProject;
        }

        return await EnrichProjectViaV1Async(config, createResult.ParspecProjectId.Value, candidate, createResult);
    }

    private static async Task<ProjectMigrationExecutionResult> EnrichProjectViaV1Async(
        ParspecMigratorConfig config,
        int projectId,
        ProjectCandidate candidate,
        ProjectMigrationExecutionResult baseResult)
    {
        var v1Payload = BuildProjectV1PatchPayload(candidate);
        if (v1Payload is null)
        {
            return baseResult with
            {
                V1EnrichmentStatus = "skipped",
                V1EnrichmentMessage = "No v1-only enrichment fields available for this project."
            };
        }

        var v1Result = await PatchParspecProjectV1Async(config, projectId, candidate, v1Payload);
        if (v1Result.IsSuccess)
        {
            return baseResult with
            {
                V1EnrichmentStatus = "applied",
                V1EnrichmentMessage = v1Result.ResponseBody,
                EstimatedValueCents = v1Payload.EstimatedValueCents
            };
        }

        return baseResult with
        {
            V1EnrichmentStatus = "failed",
            V1EnrichmentMessage = v1Result.ResponseBody,
            EstimatedValueCents = v1Payload.EstimatedValueCents
        };
    }

    private static ParspecProject? FindExistingParspecProject(
        ProjectCandidate candidate,
        ProjectV2Payload payload,
        ProjectMigrationContext context)
    {
        if (!string.IsNullOrWhiteSpace(candidate.ErpId)
            && context.ExistingProjectsByErpId.TryGetValue(candidate.ErpId, out var byErpId))
        {
            return byErpId;
        }

        if (!string.IsNullOrWhiteSpace(payload.CrmId)
            && context.ExistingProjectsByCrmId.TryGetValue(payload.CrmId, out var byCrmId))
        {
            return byCrmId;
        }

        var naturalKey = BuildProjectNaturalKey(payload.Location, payload.Name, payload.ProjectCode);
        if (!string.IsNullOrWhiteSpace(naturalKey)
            && context.ExistingProjectsByNaturalKey.TryGetValue(naturalKey, out var byNaturalKey))
        {
            return byNaturalKey;
        }

        var looseNaturalKey = BuildLooseProjectNaturalKey(payload.Location, payload.Name);
        if (!string.IsNullOrWhiteSpace(looseNaturalKey)
            && context.ExistingProjectsByLooseNaturalKey.TryGetValue(looseNaturalKey, out var byLooseNaturalKey))
        {
            return byLooseNaturalKey;
        }

        return null;
    }

    private static ProjectV2Payload BuildProjectPayload(ProjectCandidate candidate, ProjectMigrationContext context)
    {
        var countryCode = InferCountryCode(candidate.LocationState) ?? string.Empty;
        var projectCode = NullIfWhiteSpace(candidate.QuoteNumber) ?? string.Empty;
        var crmId = NullIfWhiteSpace(candidate.CrmId) ?? string.Empty;
        var stakeholders = BuildProjectStakeholders(candidate, context);

        return new ProjectV2Payload
        {
            Address = new V2AddressPayload
            {
                AddressLine1 = string.Empty,
                AddressLine2 = string.Empty,
                City = NullIfWhiteSpace(candidate.LocationCity) ?? string.Empty,
                CountryCode = countryCode,
                PostalCode = string.Empty,
                StateOrRegionCode = NormalizeParspecRegionCode(countryCode, candidate.LocationState)
            },
            ConstructionScope = string.Empty,
            CrmId = crmId,
            ErpId = candidate.ErpId ?? string.Empty,
            Location = candidate.LocationId ?? 0,
            MarketVertical = null,
            Name = candidate.Name ?? string.Empty,
            Owner = null,
            ProjectCode = projectCode,
            ProjectStakeholders = stakeholders,
            SquareFootage = candidate.SquareFootage
        };
    }

    private static ProjectV1PatchPayload? BuildProjectV1PatchPayload(ProjectCandidate candidate)
    {
        var estimatedValueCents = ToNullableCents(candidate.Valuation);
        if (!estimatedValueCents.HasValue)
        {
            return null;
        }

        return new ProjectV1PatchPayload
        {
            EstimatedValueCents = estimatedValueCents.Value
        };
    }

    private static IReadOnlyList<ProjectStakeholderPayload> BuildProjectStakeholders(
        ProjectCandidate candidate,
        ProjectMigrationContext context)
    {
        if (string.IsNullOrWhiteSpace(candidate.ErpId)
            || !context.StakeholdersByProjectErpId.TryGetValue(candidate.ErpId, out var stakeholderCandidates)
            || stakeholderCandidates.Count == 0)
        {
            return Array.Empty<ProjectStakeholderPayload>();
        }

        var stakeholders = new List<ProjectStakeholderPayload>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var stakeholder in stakeholderCandidates)
        {
            if (string.Equals(stakeholder.AccountCategory, "Manufacturer", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            int? companyId = null;
            int? contactId = null;

            if (!string.IsNullOrWhiteSpace(stakeholder.AccountCrmId)
                && context.ExistingCompaniesByCrmId.TryGetValue(stakeholder.AccountCrmId, out var company))
            {
                companyId = company.Id;
            }

            if (!companyId.HasValue
                && !string.IsNullOrWhiteSpace(stakeholder.AccountErpId)
                && context.ExistingCompaniesByErpId.TryGetValue(stakeholder.AccountErpId, out company))
            {
                companyId = company.Id;
            }

            if (!string.IsNullOrWhiteSpace(stakeholder.ContactCrmId)
                && context.ExistingContactsByCrmId.TryGetValue(stakeholder.ContactCrmId, out var contact))
            {
                contactId = contact.Id;
                if (!companyId.HasValue)
                {
                    companyId = contact.Company;
                }
            }

            if (!contactId.HasValue
                && !string.IsNullOrWhiteSpace(stakeholder.ContactExternalId)
                && context.ExistingContactsByCrmId.TryGetValue(stakeholder.ContactExternalId, out contact))
            {
                contactId = contact.Id;
                if (!companyId.HasValue)
                {
                    companyId = contact.Company;
                }
            }

            if (!companyId.HasValue && !contactId.HasValue)
            {
                continue;
            }

            var dedupeKey = $"{companyId?.ToString() ?? "-"}|{contactId?.ToString() ?? "-"}";
            if (!seen.Add(dedupeKey))
            {
                continue;
            }

            stakeholders.Add(new ProjectStakeholderPayload
            {
                Company = companyId,
                Contact = contactId
            });

            if (stakeholders.Count >= 10)
            {
                break;
            }
        }

        return stakeholders;
    }

    private static async Task<ProjectMigrationExecutionResult> CreateParspecProjectAsync(
        ParspecMigratorConfig config,
        ProjectCandidate candidate,
        ProjectV2Payload payload)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Post, "v2/projects")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"Create failed for {candidate.ErpId} ({candidate.Name}): HTTP {(int)response.StatusCode} {response.StatusCode}");
            Console.WriteLine(responseBody);

            return new ProjectMigrationExecutionResult
            {
                SourceErpId = candidate.ErpId,
                SourceName = candidate.Name,
                Status = "failed",
                Message = responseBody
            };
        }

        var createdProject = JsonSerializer.Deserialize<ParspecProject>(responseBody, ApiJsonOptions);

        return new ProjectMigrationExecutionResult
        {
            SourceErpId = candidate.ErpId,
            SourceName = candidate.Name,
            Status = "created",
            ParspecProjectId = createdProject?.Id,
            Message = responseBody
        };
    }

    private static async Task<ProjectMigrationExecutionResult> PatchParspecProjectAsync(
        ParspecMigratorConfig config,
        int projectId,
        ProjectCandidate candidate,
        ProjectV2Payload payload)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Patch, $"v2/projects/{projectId}")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"Update failed for {candidate.ErpId} ({candidate.Name}): HTTP {(int)response.StatusCode} {response.StatusCode}");
            Console.WriteLine(responseBody);

            return new ProjectMigrationExecutionResult
            {
                SourceErpId = candidate.ErpId,
                SourceName = candidate.Name,
                Status = "failed",
                Message = responseBody
            };
        }

        return new ProjectMigrationExecutionResult
        {
            SourceErpId = candidate.ErpId,
            SourceName = candidate.Name,
            Status = "updated-existing",
            ParspecProjectId = projectId,
            Message = responseBody
        };
    }

    private static async Task<ParspecV1PatchResult> PatchParspecProjectV1Async(
        ParspecMigratorConfig config,
        int projectId,
        ProjectCandidate candidate,
        ProjectV1PatchPayload payload)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Patch, $"v1/projects/{projectId}")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();
        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"V1 enrichment failed for {candidate.ErpId} ({candidate.Name}): HTTP {(int)response.StatusCode} {response.StatusCode}");
            Console.WriteLine(responseBody);
        }

        return new ParspecV1PatchResult
        {
            IsSuccess = response.IsSuccessStatusCode,
            ResponseBody = responseBody
        };
    }

    private static int? ToNullableCents(decimal? amount)
    {
        if (!amount.HasValue)
        {
            return null;
        }

        return decimal.ToInt32(decimal.Round(amount.Value * 100m, 0, MidpointRounding.AwayFromZero));
    }

    private static string BuildProjectNaturalKey(ParspecProject project) =>
        BuildProjectNaturalKey(project.Location, project.Name, project.ProjectCode);

    private static string BuildProjectNaturalKey(int locationId, string? name, string? projectCode)
    {
        var normalizedName = NullIfWhiteSpace(name)?.ToUpperInvariant() ?? string.Empty;
        var normalizedCode = NullIfWhiteSpace(projectCode)?.ToUpperInvariant() ?? string.Empty;
        return $"{locationId}|{normalizedName}|{normalizedCode}";
    }

    private static string BuildLooseProjectNaturalKey(int locationId, string? name)
    {
        var normalizedName = NullIfWhiteSpace(name)?.ToUpperInvariant() ?? string.Empty;
        return $"{locationId}|{normalizedName}";
    }

    private static async Task<ManufacturerMigrationContext> BuildManufacturerMigrationContextAsync(ParspecMigratorConfig config)
    {
        var existingManufacturers = await LoadAllParspecManufacturersAsync(config);

        return new ManufacturerMigrationContext
        {
            ExistingManufacturersByErpId = existingManufacturers
                .Where(manufacturer => !string.IsNullOrWhiteSpace(manufacturer.ErpId))
                .GroupBy(manufacturer => manufacturer.ErpId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingManufacturersByName = existingManufacturers
                .Where(manufacturer => !string.IsNullOrWhiteSpace(manufacturer.Name))
                .GroupBy(manufacturer => manufacturer.Name!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase)
        };
    }

    private static async Task<List<ParspecManufacturer>> LoadAllParspecManufacturersAsync(ParspecMigratorConfig config)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var manufacturers = new List<ParspecManufacturer>();
        var start = 0;
        const int pageSize = 200;

        while (true)
        {
            using var response = await client.GetAsync($"v2/manufacturers?start={start}&limit={pageSize}");
            var body = await response.Content.ReadAsStringAsync();
            response.EnsureSuccessStatusCode();

            var payload = JsonSerializer.Deserialize<ParspecManufacturerListResponse>(body, ApiJsonOptions)
                ?? new ParspecManufacturerListResponse();

            manufacturers.AddRange(payload.Results);

            if (payload.Results.Count < pageSize)
            {
                break;
            }

            start += pageSize;
        }

        return manufacturers;
    }

    private static async Task<ManufacturerMigrationExecutionResult> CreateOrUpdateManufacturerAsync(
        ParspecMigratorConfig config,
        ManufacturerCandidate candidate,
        ManufacturerMigrationContext context)
    {
        var existingManufacturer = FindExistingParspecManufacturer(candidate, context);
        var payload = BuildManufacturerPayload(candidate);

        if (existingManufacturer is not null)
        {
            var updateResult = await PatchParspecManufacturerAsync(config, existingManufacturer.Id, candidate, payload);
            if (updateResult.Status == "updated-existing")
            {
                var updated = new ParspecManufacturer
                {
                    Id = existingManufacturer.Id,
                    ErpId = payload.ErpId,
                    Name = payload.Name
                };

                if (!string.IsNullOrWhiteSpace(updated.ErpId))
                {
                    context.ExistingManufacturersByErpId[updated.ErpId] = updated;
                }

                if (!string.IsNullOrWhiteSpace(updated.Name))
                {
                    context.ExistingManufacturersByName[updated.Name] = updated;
                }
            }

            return updateResult;
        }

        var createResult = await CreateParspecManufacturerAsync(config, candidate, payload);
        if (createResult.Status != "created" || createResult.ParspecManufacturerId is null)
        {
            return createResult;
        }

        var createdManufacturer = new ParspecManufacturer
        {
            Id = createResult.ParspecManufacturerId.Value,
            ErpId = payload.ErpId,
            Name = payload.Name
        };

        if (!string.IsNullOrWhiteSpace(createdManufacturer.ErpId))
        {
            context.ExistingManufacturersByErpId[createdManufacturer.ErpId] = createdManufacturer;
        }

        if (!string.IsNullOrWhiteSpace(createdManufacturer.Name))
        {
            context.ExistingManufacturersByName[createdManufacturer.Name] = createdManufacturer;
        }

        return createResult;
    }

    private static ParspecManufacturer? FindExistingParspecManufacturer(
        ManufacturerCandidate candidate,
        ManufacturerMigrationContext context)
    {
        if (!string.IsNullOrWhiteSpace(candidate.ErpId)
            && context.ExistingManufacturersByErpId.TryGetValue(candidate.ErpId, out var byErpId))
        {
            return byErpId;
        }

        if (!string.IsNullOrWhiteSpace(candidate.Name)
            && context.ExistingManufacturersByName.TryGetValue(candidate.Name, out var byName))
        {
            return byName;
        }

        return null;
    }

    private static ManufacturerV2Payload BuildManufacturerPayload(ManufacturerCandidate candidate)
    {
        var address = candidate.MailAddress;
        var countryCode = NormalizeCountryCode(address.CountryCode) ?? InferCountryCode(address.StateOrRegionCode) ?? string.Empty;
        var stateOrRegionCode = NormalizeParspecRegionCode(countryCode, address.StateOrRegionCode);
        var abbreviation = NullIfWhiteSpace(candidate.DisplayId);
        var website = NormalizeWebsite(candidate.Website);

        return new ManufacturerV2Payload
        {
            Abbreviations = string.IsNullOrWhiteSpace(abbreviation) ? Array.Empty<string>() : [abbreviation],
            Active = true,
            Address = new V2AddressPayload
            {
                AddressLine1 = NullIfWhiteSpace(address.AddressLine1) ?? string.Empty,
                AddressLine2 = NullIfWhiteSpace(address.AddressLine2) ?? string.Empty,
                City = NullIfWhiteSpace(address.City) ?? string.Empty,
                CountryCode = countryCode,
                PostalCode = NullIfWhiteSpace(address.PostalCode) ?? string.Empty,
                StateOrRegionCode = stateOrRegionCode
            },
            EdiVendor = false,
            ErpId = candidate.ErpId ?? string.Empty,
            Incentive = false,
            Name = candidate.Name ?? string.Empty,
            ParspecManufacturerId = null,
            PaymentTerms = string.Empty,
            VisibleToAllLocations = true,
            VisibleToLocations = null,
            Website = website ?? string.Empty
        };
    }

    private static async Task<ManufacturerMigrationExecutionResult> CreateParspecManufacturerAsync(
        ParspecMigratorConfig config,
        ManufacturerCandidate candidate,
        ManufacturerV2Payload payload)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Post, "v2/manufacturers")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"Create failed for {candidate.ErpId} ({candidate.Name}): HTTP {(int)response.StatusCode} {response.StatusCode}");
            Console.WriteLine(responseBody);

            return new ManufacturerMigrationExecutionResult
            {
                SourceErpId = candidate.ErpId,
                SourceName = candidate.Name,
                Status = "failed",
                Message = responseBody
            };
        }

        var createdManufacturer = JsonSerializer.Deserialize<ParspecManufacturer>(responseBody, ApiJsonOptions);

        return new ManufacturerMigrationExecutionResult
        {
            SourceErpId = candidate.ErpId,
            SourceName = candidate.Name,
            Status = "created",
            ParspecManufacturerId = createdManufacturer?.Id,
            Message = responseBody
        };
    }

    private static async Task<ManufacturerMigrationExecutionResult> PatchParspecManufacturerAsync(
        ParspecMigratorConfig config,
        int manufacturerId,
        ManufacturerCandidate candidate,
        ManufacturerV2Payload payload)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Patch, $"v2/manufacturers/{manufacturerId}")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"Update failed for {candidate.ErpId} ({candidate.Name}): HTTP {(int)response.StatusCode} {response.StatusCode}");
            Console.WriteLine(responseBody);

            return new ManufacturerMigrationExecutionResult
            {
                SourceErpId = candidate.ErpId,
                SourceName = candidate.Name,
                Status = "failed",
                Message = responseBody
            };
        }

        return new ManufacturerMigrationExecutionResult
        {
            SourceErpId = candidate.ErpId,
            SourceName = candidate.Name,
            Status = "updated-existing",
            ParspecManufacturerId = manufacturerId,
            Message = responseBody
        };
    }

    private static CompanyFieldCoverage BuildCompanyCoverage(
        string? erpId,
        string? name,
        string? businessType,
        string? crmId,
        string? outsideSalesCrmUserId,
        string? email,
        string? phone,
        string? website,
        CompanyAddress soldAddress,
        CompanyAddress billAddress,
        CompanyAddress shipAddress,
        string? parentErpId,
        string? orderEntryNotes,
        string? internalNotes,
        string? termText,
        string? invoiceTermText)
    {
        var hasNotes = !string.IsNullOrWhiteSpace(orderEntryNotes)
            || !string.IsNullOrWhiteSpace(internalNotes)
            || !string.IsNullOrWhiteSpace(termText)
            || !string.IsNullOrWhiteSpace(invoiceTermText);

        return new CompanyFieldCoverage
        {
            ResolvedFields = new List<string>
            {
                !string.IsNullOrWhiteSpace(erpId) ? "erpId" : string.Empty,
                !string.IsNullOrWhiteSpace(name) ? "name" : string.Empty,
                !string.IsNullOrWhiteSpace(businessType) ? "businessType" : string.Empty,
                !string.IsNullOrWhiteSpace(crmId) ? "crmId" : string.Empty,
                !string.IsNullOrWhiteSpace(email) ? "email" : string.Empty,
                !string.IsNullOrWhiteSpace(phone) ? "phone" : string.Empty,
                !string.IsNullOrWhiteSpace(website) ? "website" : string.Empty,
                soldAddress.HasContent ? "address" : string.Empty,
                hasNotes ? "notes" : string.Empty,
                !string.IsNullOrWhiteSpace(outsideSalesCrmUserId) ? "outsideSalesAgent.crmLookup" : string.Empty,
                "visibleToAllLocations(default)" ,
                "visibleToLocations(default current sandbox)"
            }.Where(value => !string.IsNullOrWhiteSpace(value)).ToList(),
            UnresolvedFields = new List<string>
            {
                "duns"
            },
            RelatedObjects = new List<string>
            {
                billAddress.HasContent ? "companyRole:BILL_TO" : string.Empty,
                shipAddress.HasContent ? "companyRole:SHIP_TO" : string.Empty,
                !string.IsNullOrWhiteSpace(parentErpId) ? "companyRelationship:PARENT" : string.Empty
            }.Where(value => !string.IsNullOrWhiteSpace(value)).ToList()
        };
    }

    private static IReadOnlyList<DestinationFieldCoverage> BuildCompanyFieldCoverage(IReadOnlyList<CompanyCandidate> companies)
    {
        var total = companies.Count;
        return
        [
            new DestinationFieldCoverage("erpId", "direct", "src.Account.AccountId", total, companies.Count(company => !string.IsNullOrWhiteSpace(company.ErpId)), "Strong primary key candidate for Parspec company ERP id."),
            new DestinationFieldCoverage("name", "direct", "src.Account.DISTRIBUTORNAME", total, companies.Count(company => !string.IsNullOrWhiteSpace(company.Name)), "Best primary company display name."),
            new DestinationFieldCoverage("businessType", "direct", "src.Account.ROLE", total, companies.Count(company => !string.IsNullOrWhiteSpace(company.BusinessType)), "Maps customer role such as Contractor, Engineer, Architect, End User."),
            new DestinationFieldCoverage("address", "direct", "src.Account.SOLD* fields", total, companies.Count(company => company.SoldToAddress.HasContent), "Use sold-to address as the base company address; preserve ship-to as a company role."),
            new DestinationFieldCoverage("crmId", "derived", "Join src.Account to AO.Account on external id + role", total, companies.Count(company => !string.IsNullOrWhiteSpace(company.CrmId)), "Resolvable for most active customer rows through AO.Account."),
            new DestinationFieldCoverage("outsideSalesAgent", "derived", "src.Account.SALESUSERID -> Parspec user by CRM id", total, companies.Count(company => !string.IsNullOrWhiteSpace(company.OutsideSalesCrmUserId)), "Source-side owner exists broadly, but final Parspec user-id lookup depends on migrated users in destination."),
            new DestinationFieldCoverage("email", "direct", "src.Account.EMAIL (raw distributor email or contact-derived fallback)", total, companies.Count(company => !string.IsNullOrWhiteSpace(company.Email)), "Now recoverable for many companies through distributor-phone email or preferred contact fallback."),
            new DestinationFieldCoverage("phone", "direct", "src.Account.PHONE", total, companies.Count(company => !string.IsNullOrWhiteSpace(company.Phone)), "Reasonable company phone candidate."),
            new DestinationFieldCoverage("notes", "direct", "src.Account.ORDERENTRYNOTES / INTERNALNOTES / TERMTEXT / INVOICETERMTEXT", total, companies.Count(company => company.HasNotesContent), "Recoverable for a subset of companies from raw Oasis notes and terms fields."),
            new DestinationFieldCoverage("website", "direct", "src.Account.WEB", total, companies.Count(company => !string.IsNullOrWhiteSpace(company.Website)), "Website coverage is partial but clean."),
            new DestinationFieldCoverage("visibleToAllLocations", "default", "Migration policy default", total, total, "Can be defaulted to true for first pass if per-company location scoping is not required."),
            new DestinationFieldCoverage("visibleToLocations", "default", "Migration policy / sandbox location mapping", total, total, "Current sandbox can use location 2592; production policy still needs confirmation."),
            new DestinationFieldCoverage("duns", "unresolved", "No source found yet", total, 0, "No obvious source in src.Account or Account_Origin output.")
        ];
    }

    private static string? NormalizeCountryCode(string? value)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            return null;
        }

        return value.Trim().ToUpperInvariant() switch
        {
            "CAN" or "CANADA" => "CA",
            "USA" or "US" or "UNITED STATES" => "US",
            _ => value.Trim()
        };
    }

    private static string? NormalizeRegionCode(string? value)
    {
        return string.IsNullOrWhiteSpace(value) ? null : value.Trim().ToUpperInvariant();
    }

    private static string? NormalizeParspecRegionCode(string? countryCode, string? regionCode)
    {
        var normalizedCountry = NormalizeCountryCode(countryCode);
        var normalizedRegion = NormalizeSourceRegionCode(regionCode, normalizedCountry);

        if (string.IsNullOrWhiteSpace(normalizedRegion))
        {
            return null;
        }

        if (string.Equals(normalizedCountry, "CA", StringComparison.OrdinalIgnoreCase)
            || string.Equals(normalizedCountry, "US", StringComparison.OrdinalIgnoreCase))
        {
            if (!normalizedRegion.Contains('-', StringComparison.Ordinal))
            {
                return $"{normalizedCountry}-{normalizedRegion}";
            }
        }

        return normalizedRegion;
    }

    private static IReadOnlyList<int> GetConfiguredLocationIds(ParspecMigratorConfig config)
    {
        var ids = config.LocationMappings.Values
            .Where(value => value > 0)
            .Distinct()
            .OrderBy(value => value)
            .ToList();

        return ids.Count > 0 ? ids : [2592];
    }

    private static CompanyCreatePayload BuildCompanyCreatePayload(
        CompanyCandidate candidate,
        IReadOnlyList<UserCandidate> sourceUsers,
        IReadOnlyList<ParspecUser> parspecUsers,
        IReadOnlyList<int> locationIds)
    {
        var address = SelectPrimaryCompanyAddress(candidate);
        var countryCode = NormalizeCountryCode(address.CountryCode) ?? InferCountryCode(address.StateOrRegionCode) ?? string.Empty;
        var regionCode = NormalizeSourceRegionCode(address.StateOrRegionCode, countryCode);
        var website = NormalizeWebsite(candidate.Website) ?? string.Empty;
        var notes = BuildCompanyNotes(candidate);
        var outsideSalesAgent = ResolveOutsideSalesAgentId(candidate.OutsideSalesCrmUserId, sourceUsers, parspecUsers);

        return new CompanyCreatePayload
        {
            Name = candidate.Name,
            ErpId = candidate.ErpId,
            CrmId = string.Empty,
            BusinessType = NormalizeCompanyBusinessType(candidate.BusinessType),
            Email = NormalizeEmail(candidate.Email) ?? string.Empty,
            Phone = NullIfWhiteSpace(candidate.Phone) ?? string.Empty,
            Website = website,
            AddressLine1 = NullIfWhiteSpace(address.AddressLine1) ?? string.Empty,
            AddressLine2 = NullIfWhiteSpace(address.AddressLine2) ?? string.Empty,
            City = NullIfWhiteSpace(address.City) ?? string.Empty,
            State = regionCode ?? string.Empty,
            ZipCode = NullIfWhiteSpace(address.PostalCode) ?? string.Empty,
            Country = countryCode,
            Notes = notes ?? string.Empty,
            Duns = null,
            OutsideSalesAgent = outsideSalesAgent,
            VisibleToAllLocations = true,
            VisibleToLocations = null
        };
    }

    private static CompanyAddress SelectPrimaryCompanyAddress(CompanyCandidate candidate)
    {
        if (candidate.SoldToAddress.HasContent)
        {
            return candidate.SoldToAddress;
        }

        if (candidate.BillToAddress.HasContent)
        {
            return candidate.BillToAddress;
        }

        if (candidate.ShipToAddress.HasContent)
        {
            return candidate.ShipToAddress;
        }

        return new CompanyAddress();
    }

    private static string? BuildCompanyNotes(CompanyCandidate candidate)
    {
        var parts = new List<string>();

        AddLabeledNote(parts, "Order entry notes", candidate.OrderEntryNotes);
        AddLabeledNote(parts, "Internal notes", candidate.InternalNotes);
        AddLabeledNote(parts, "Terms", candidate.TermText);
        AddLabeledNote(parts, "Invoice terms", candidate.InvoiceTermText);
        AddLabeledNote(parts, "Tax ID", candidate.TaxId);
        AddLabeledNote(parts, "Parent account", candidate.ParentErpId);

        return parts.Count == 0 ? null : string.Join(Environment.NewLine + Environment.NewLine, parts);
    }

    private static void AddLabeledNote(ICollection<string> parts, string label, string? value)
    {
        var normalized = NullIfWhiteSpace(value);
        if (!string.IsNullOrWhiteSpace(normalized))
        {
            parts.Add($"{label}: {normalized}");
        }
    }

    private static string? BuildContactNotes(ContactCandidate candidate)
    {
        var parts = new List<string>();

        AddLabeledNote(parts, "Department", candidate.Department);
        AddLabeledNote(parts, "Extension", NormalizeExtension(candidate.Extension));
        AddLabeledNote(parts, "Mobile", candidate.Mobile);
        AddLabeledNote(parts, "Fax", candidate.Fax);

        if (candidate.HomeAddress.HasContent)
        {
            var homeAddress = FormatAddress(candidate.HomeAddress);
            if (!string.IsNullOrWhiteSpace(homeAddress))
            {
                parts.Add($"Home address: {homeAddress}");
            }
        }

        AddLabeledNote(parts, "Source contact id", candidate.SourceContactId);
        AddLabeledNote(parts, "Source external id", candidate.ExternalId);

        return parts.Count == 0 ? null : string.Join(Environment.NewLine + Environment.NewLine, parts);
    }

    private static string? SelectPrimaryContactPhone(ContactCandidate candidate)
    {
        return NullIfWhiteSpace(candidate.Phone)
            ?? NullIfWhiteSpace(candidate.Mobile);
    }

    private static string? NormalizeExtension(string? value)
    {
        var normalized = NullIfWhiteSpace(value);
        if (normalized is null || normalized is "." or "-")
        {
            return null;
        }

        return normalized;
    }

    private static string? FormatAddress(CompanyAddress address)
    {
        var parts = new[]
        {
            NullIfWhiteSpace(address.AddressLine1),
            NullIfWhiteSpace(address.AddressLine2),
            NullIfWhiteSpace(address.City),
            NullIfWhiteSpace(address.StateOrRegionCode),
            NullIfWhiteSpace(address.PostalCode),
            NullIfWhiteSpace(address.CountryCode)
        }
        .Where(part => !string.IsNullOrWhiteSpace(part))
        .ToList();

        return parts.Count == 0 ? null : string.Join(", ", parts);
    }

    private static bool AddressesMatch(CompanyAddress sourceAddress, ParspecCompany company)
    {
        var sourceCountryCode = NormalizeCountryCode(sourceAddress.CountryCode) ?? InferCountryCode(sourceAddress.StateOrRegionCode) ?? string.Empty;
        var sourceStateOrRegionCode = NormalizeParspecRegionCode(sourceCountryCode, sourceAddress.StateOrRegionCode) ?? string.Empty;

        return string.Equals(NullIfWhiteSpace(sourceAddress.AddressLine1) ?? string.Empty, NullIfWhiteSpace(company.AddressLine1) ?? string.Empty, StringComparison.OrdinalIgnoreCase)
            && string.Equals(NullIfWhiteSpace(sourceAddress.AddressLine2) ?? string.Empty, NullIfWhiteSpace(company.AddressLine2) ?? string.Empty, StringComparison.OrdinalIgnoreCase)
            && string.Equals(NullIfWhiteSpace(sourceAddress.City) ?? string.Empty, NullIfWhiteSpace(company.City) ?? string.Empty, StringComparison.OrdinalIgnoreCase)
            && string.Equals(sourceStateOrRegionCode, NullIfWhiteSpace(company.State) ?? string.Empty, StringComparison.OrdinalIgnoreCase)
            && string.Equals(NullIfWhiteSpace(sourceAddress.PostalCode) ?? string.Empty, NullIfWhiteSpace(company.ZipCode) ?? string.Empty, StringComparison.OrdinalIgnoreCase)
            && string.Equals(sourceCountryCode, NormalizeCountryCode(company.Country) ?? string.Empty, StringComparison.OrdinalIgnoreCase);
    }

    private static ContactV2Payload BuildContactPayload(ContactCandidate candidate, ParspecCompany company)
    {
        var phone = SelectPrimaryContactPhone(candidate) ?? string.Empty;
        var notes = BuildContactNotes(candidate) ?? string.Empty;
        var useInheritedAddress = !candidate.WorkAddress.HasContent || AddressesMatch(candidate.WorkAddress, company);
        var address = useInheritedAddress
            ? null
            : new V2AddressPayload
            {
                AddressLine1 = NullIfWhiteSpace(candidate.WorkAddress.AddressLine1) ?? string.Empty,
                AddressLine2 = NullIfWhiteSpace(candidate.WorkAddress.AddressLine2) ?? string.Empty,
                City = NullIfWhiteSpace(candidate.WorkAddress.City) ?? string.Empty,
                CountryCode = NormalizeCountryCode(candidate.WorkAddress.CountryCode) ?? InferCountryCode(candidate.WorkAddress.StateOrRegionCode) ?? string.Empty,
                PostalCode = NullIfWhiteSpace(candidate.WorkAddress.PostalCode) ?? string.Empty,
                StateOrRegionCode = NormalizeParspecRegionCode(
                    NormalizeCountryCode(candidate.WorkAddress.CountryCode) ?? InferCountryCode(candidate.WorkAddress.StateOrRegionCode) ?? string.Empty,
                    candidate.WorkAddress.StateOrRegionCode)
            };

        return new ContactV2Payload
        {
            Company = company.Id,
            CrmId = NullIfWhiteSpace(candidate.CrmId) ?? string.Empty,
            Email = NormalizeEmail(candidate.Email) ?? string.Empty,
            FirstName = NullIfWhiteSpace(candidate.FirstName) ?? string.Empty,
            JobTitle = NullIfWhiteSpace(candidate.JobTitle) ?? string.Empty,
            LastName = NullIfWhiteSpace(candidate.LastName) ?? string.Empty,
            Notes = notes,
            OutsideSalesAgent = null,
            Phone = phone,
            AddressInheritedFromCompany = useInheritedAddress,
            Address = address
        };
    }

    private static int? ResolveOutsideSalesAgentId(
        string? outsideSalesCrmUserId,
        IReadOnlyList<UserCandidate> sourceUsers,
        IReadOnlyList<ParspecUser> parspecUsers)
    {
        if (string.IsNullOrWhiteSpace(outsideSalesCrmUserId))
        {
            return null;
        }

        var sourceUser = sourceUsers.FirstOrDefault(user =>
            string.Equals(user.AoUserId, outsideSalesCrmUserId, StringComparison.OrdinalIgnoreCase));

        if (sourceUser is null || string.IsNullOrWhiteSpace(sourceUser.OasisUserId))
        {
            return null;
        }

        var parspecUser = parspecUsers.FirstOrDefault(user =>
            string.Equals(user.ErpId, sourceUser.OasisUserId, StringComparison.OrdinalIgnoreCase));

        return parspecUser?.Id;
    }

    private static string? NormalizeWebsite(string? value)
    {
        var website = NullIfWhiteSpace(value);
        if (website is null)
        {
            return null;
        }

        if (string.Equals(website, "NONE", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        website = website.Replace(",", ".", StringComparison.Ordinal);

        if (website.Contains(' ', StringComparison.Ordinal))
        {
            return null;
        }

        if (website.StartsWith("http://", StringComparison.OrdinalIgnoreCase)
            || website.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
        {
            return website;
        }

        if (!website.Contains('.', StringComparison.Ordinal))
        {
            return null;
        }

        return $"https://{website}";
    }

    private static string? NormalizeEmail(string? value)
    {
        var email = NullIfWhiteSpace(value);
        if (email is null)
        {
            return null;
        }

        var ltIndex = email.IndexOf('<');
        var gtIndex = email.IndexOf('>');
        if (ltIndex >= 0 && gtIndex > ltIndex)
        {
            email = email[(ltIndex + 1)..gtIndex];
        }

        email = email.Trim().Trim('>', '<').Replace(",", ".", StringComparison.Ordinal);

        return email.Contains('@', StringComparison.Ordinal) ? email : null;
    }

    private static string NormalizeCompanyBusinessType(string? value)
    {
        var normalized = NullIfWhiteSpace(value);
        if (normalized is null)
        {
            return string.Empty;
        }

        return normalized switch
        {
            "Architect" => "Architect",
            "Contractor" => "Contractor",
            "Distributor" => "Distributor",
            "Engineer" => "Engineer",
            "Designer" => "Architect",
            _ => string.Empty
        };
    }

    private static string? InferCountryCode(string? regionCode)
    {
        var normalizedRegion = NormalizeRegionCode(regionCode);
        if (normalizedRegion is null)
        {
            return null;
        }

        if (CanadianRegionCodes.Contains(normalizedRegion))
        {
            return "CA";
        }

        if (UnitedStatesRegionCodes.Contains(normalizedRegion))
        {
            return "US";
        }

        return null;
    }

    private static string? NormalizeSourceRegionCode(string? value, string? countryCode)
    {
        var regionCode = NormalizeRegionCode(value);
        if (regionCode is null)
        {
            return null;
        }

        if (string.Equals(countryCode, "CA", StringComparison.OrdinalIgnoreCase))
        {
            return regionCode switch
            {
                "BR" => "BC",
                "AL" => "AB",
                "A" => "AB",
                "YK" => "YT",
                _ => regionCode
            };
        }

        return regionCode;
    }

    private static string? NullIfWhiteSpace(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim();

    private static async Task<CompanyMigrationContext> BuildCompanyMigrationContextAsync(ParspecMigratorConfig config)
    {
        var sourceUsers = await LoadUserCandidatesAsync(
            config.BusinessConnectionString,
            config.LocationMappings
                .Where(pair => pair.Value > 0)
                .ToDictionary(pair => pair.Key, pair => pair.Value, StringComparer.OrdinalIgnoreCase));
        var parspecUsers = await LoadParspecUsersAsync(config);
        var existingCompanies = await LoadAllParspecCompaniesAsync(config);

        return new CompanyMigrationContext
        {
            LocationIds = GetConfiguredLocationIds(config),
            SourceUsers = sourceUsers,
            ParspecUsers = parspecUsers,
            ExistingCompaniesByErpId = existingCompanies
                .Where(company => !string.IsNullOrWhiteSpace(company.ErpId))
                .GroupBy(company => company.ErpId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingCompaniesByName = existingCompanies
                .Where(company => !string.IsNullOrWhiteSpace(company.Name))
                .GroupBy(company => company.Name!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingCompaniesByCrmId = existingCompanies
                .Where(company => !string.IsNullOrWhiteSpace(company.CrmId))
                .GroupBy(company => company.CrmId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase)
        };
    }

    private static async Task<List<ParspecCompany>> LoadAllParspecCompaniesAsync(ParspecMigratorConfig config)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var companies = new List<ParspecCompany>();
        var start = 0;
        const int pageSize = 200;

        while (true)
        {
            using var response = await client.GetAsync($"v2/companies?start={start}&limit={pageSize}");
            var body = await response.Content.ReadAsStringAsync();
            response.EnsureSuccessStatusCode();

            var payload = JsonSerializer.Deserialize<ParspecCompanyListResponse>(body, ApiJsonOptions)
                ?? new ParspecCompanyListResponse();

            companies.AddRange(payload.Results);

            if (payload.Results.Count < pageSize)
            {
                break;
            }

            start += pageSize;
        }

        return companies;
    }

    private static async Task<ContactMigrationContext> BuildContactMigrationContextAsync(ParspecMigratorConfig config)
    {
        var existingCompanies = await LoadAllParspecCompaniesAsync(config);
        var existingContacts = await LoadAllParspecContactsAsync(config);

        return new ContactMigrationContext
        {
            ExistingCompaniesByErpId = existingCompanies
                .Where(company => !string.IsNullOrWhiteSpace(company.ErpId))
                .GroupBy(company => company.ErpId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingContactsByCrmId = existingContacts
                .Where(contact => !string.IsNullOrWhiteSpace(contact.CrmId))
                .GroupBy(contact => contact.CrmId!, StringComparer.OrdinalIgnoreCase)
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase),
            ExistingContactsByNaturalKey = existingContacts
                .GroupBy(BuildContactNaturalKey, StringComparer.OrdinalIgnoreCase)
                .Where(group => !string.IsNullOrWhiteSpace(group.Key))
                .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase)
        };
    }

    private static async Task<List<ParspecContact>> LoadAllParspecContactsAsync(ParspecMigratorConfig config)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var contacts = new List<ParspecContact>();
        var start = 0;
        const int pageSize = 200;

        while (true)
        {
            using var response = await client.GetAsync($"v2/contacts?start={start}&limit={pageSize}");
            var body = await response.Content.ReadAsStringAsync();
            response.EnsureSuccessStatusCode();

            var payload = JsonSerializer.Deserialize<ParspecContactListResponse>(body, ApiJsonOptions)
                ?? new ParspecContactListResponse();

            contacts.AddRange(payload.Results);

            if (payload.Results.Count < pageSize)
            {
                break;
            }

            start += pageSize;
        }

        return contacts;
    }

    private static async Task<ContactMigrationExecutionResult> CreateOrUpdateContactAsync(
        ParspecMigratorConfig config,
        ContactCandidate candidate,
        ContactMigrationContext context)
    {
        if (string.IsNullOrWhiteSpace(candidate.CompanyErpId)
            || !context.ExistingCompaniesByErpId.TryGetValue(candidate.CompanyErpId, out var company))
        {
            return new ContactMigrationExecutionResult
            {
                SourceContactId = candidate.SourceContactId,
                SourceName = $"{candidate.FirstName} {candidate.LastName}".Trim(),
                Status = "failed",
                Message = $"No Parspec company found for source company erpId {candidate.CompanyErpId ?? "(blank)"}."
            };
        }

        var payload = BuildContactPayload(candidate, company);
        var existingContact = FindExistingParspecContact(candidate, company.Id, context);
        if (existingContact is not null)
        {
            var updateResult = await PatchParspecContactAsync(config, existingContact.Id, candidate, payload);
            if (updateResult.Status == "updated-existing")
            {
                context.ExistingContactsByCrmId[payload.CrmId] = new ParspecContact
                {
                    Id = existingContact.Id,
                    Company = company.Id,
                    CrmId = payload.CrmId,
                    FirstName = payload.FirstName,
                    LastName = payload.LastName,
                    Email = payload.Email
                };

                var naturalKey = BuildContactNaturalKey(company.Id, payload.FirstName, payload.LastName, payload.Email);
                if (!string.IsNullOrWhiteSpace(naturalKey))
                {
                    context.ExistingContactsByNaturalKey[naturalKey] = context.ExistingContactsByCrmId[payload.CrmId];
                }
            }

            return updateResult;
        }

        var createResult = await CreateParspecContactAsync(config, candidate, payload);
        if (createResult.Status != "created" || createResult.ParspecContactId is null)
        {
            return createResult;
        }

        var createdContact = new ParspecContact
        {
            Id = createResult.ParspecContactId.Value,
            Company = company.Id,
            CrmId = payload.CrmId,
            FirstName = payload.FirstName,
            LastName = payload.LastName,
            Email = payload.Email
        };

        if (!string.IsNullOrWhiteSpace(createdContact.CrmId))
        {
            context.ExistingContactsByCrmId[createdContact.CrmId] = createdContact;
        }

        var createdNaturalKey = BuildContactNaturalKey(createdContact);
        if (!string.IsNullOrWhiteSpace(createdNaturalKey))
        {
            context.ExistingContactsByNaturalKey[createdNaturalKey] = createdContact;
        }

        return createResult;
    }

    private static ParspecContact? FindExistingParspecContact(
        ContactCandidate candidate,
        int companyId,
        ContactMigrationContext context)
    {
        if (!string.IsNullOrWhiteSpace(candidate.CrmId)
            && context.ExistingContactsByCrmId.TryGetValue(candidate.CrmId, out var byCrmId))
        {
            return byCrmId;
        }

        var naturalKey = BuildContactNaturalKey(companyId, candidate.FirstName, candidate.LastName, candidate.Email);
        if (!string.IsNullOrWhiteSpace(naturalKey)
            && context.ExistingContactsByNaturalKey.TryGetValue(naturalKey, out var byNaturalKey))
        {
            return byNaturalKey;
        }

        return null;
    }

    private static async Task<ContactMigrationExecutionResult> CreateParspecContactAsync(
        ParspecMigratorConfig config,
        ContactCandidate candidate,
        ContactV2Payload payload)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Post, "v2/contacts")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"Create failed for {candidate.SourceContactId} ({candidate.FirstName} {candidate.LastName}): HTTP {(int)response.StatusCode} {response.StatusCode}");
            Console.WriteLine(responseBody);

            return new ContactMigrationExecutionResult
            {
                SourceContactId = candidate.SourceContactId,
                SourceName = $"{candidate.FirstName} {candidate.LastName}".Trim(),
                Status = "failed",
                Message = responseBody
            };
        }

        var createdContact = JsonSerializer.Deserialize<ParspecContact>(responseBody, ApiJsonOptions);

        return new ContactMigrationExecutionResult
        {
            SourceContactId = candidate.SourceContactId,
            SourceName = $"{candidate.FirstName} {candidate.LastName}".Trim(),
            Status = "created",
            ParspecContactId = createdContact?.Id,
            Message = responseBody
        };
    }

    private static async Task<ContactMigrationExecutionResult> PatchParspecContactAsync(
        ParspecMigratorConfig config,
        int contactId,
        ContactCandidate candidate,
        ContactV2Payload payload)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Patch, $"v2/contacts/{contactId}")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"Update failed for {candidate.SourceContactId} ({candidate.FirstName} {candidate.LastName}): HTTP {(int)response.StatusCode} {response.StatusCode}");
            Console.WriteLine(responseBody);

            return new ContactMigrationExecutionResult
            {
                SourceContactId = candidate.SourceContactId,
                SourceName = $"{candidate.FirstName} {candidate.LastName}".Trim(),
                Status = "failed",
                Message = responseBody
            };
        }

        return new ContactMigrationExecutionResult
        {
            SourceContactId = candidate.SourceContactId,
            SourceName = $"{candidate.FirstName} {candidate.LastName}".Trim(),
            Status = "updated-existing",
            ParspecContactId = contactId,
            Message = responseBody
        };
    }

    private static string BuildContactNaturalKey(ParspecContact contact) =>
        BuildContactNaturalKey(contact.Company, contact.FirstName, contact.LastName, contact.Email);

    private static string BuildContactNaturalKey(int companyId, string? firstName, string? lastName, string? email)
    {
        var normalizedFirstName = NullIfWhiteSpace(firstName)?.ToUpperInvariant() ?? string.Empty;
        var normalizedLastName = NullIfWhiteSpace(lastName)?.ToUpperInvariant() ?? string.Empty;
        var normalizedEmail = NormalizeEmail(email)?.ToUpperInvariant() ?? string.Empty;
        return $"{companyId}|{normalizedFirstName}|{normalizedLastName}|{normalizedEmail}";
    }

    private static async Task<CompanyMigrationExecutionResult> CreateOrUpdateCompanyAsync(
        ParspecMigratorConfig config,
        CompanyCandidate candidate,
        CompanyMigrationContext context)
    {
        var existingCompany = FindExistingParspecCompany(candidate, context);
        if (existingCompany is not null)
        {
            await PatchCompanyAddressAsync(config, existingCompany.Id, SelectPrimaryCompanyAddress(candidate));

            return new CompanyMigrationExecutionResult
            {
                SourceErpId = candidate.ErpId,
                SourceName = candidate.Name,
                Status = "updated-existing",
                ParspecCompanyId = existingCompany.Id,
                Message = $"Existing Parspec company reused for ERP id {candidate.ErpId}."
            };
        }

        var payload = BuildCompanyCreatePayload(candidate, context.SourceUsers, context.ParspecUsers, context.LocationIds);
        var createResult = await CreateParspecCompanyAsync(config, candidate, payload);
        if (createResult.Status != "created" || createResult.ParspecCompanyId is null)
        {
            return createResult;
        }

        await PatchCompanyAddressAsync(config, createResult.ParspecCompanyId.Value, SelectPrimaryCompanyAddress(candidate));

        var createdCompany = new ParspecCompany
        {
            Id = createResult.ParspecCompanyId.Value,
            Name = candidate.Name,
            ErpId = candidate.ErpId,
            CrmId = string.Empty,
            BusinessType = candidate.BusinessType,
            Email = candidate.Email
        };

        if (!string.IsNullOrWhiteSpace(createdCompany.ErpId))
        {
            context.ExistingCompaniesByErpId[createdCompany.ErpId] = createdCompany;
        }

        if (!string.IsNullOrWhiteSpace(createdCompany.Name))
        {
            context.ExistingCompaniesByName[createdCompany.Name] = createdCompany;
        }

        return createResult;
    }

    private static ParspecCompany? FindExistingParspecCompany(
        CompanyCandidate candidate,
        CompanyMigrationContext context)
    {
        if (!string.IsNullOrWhiteSpace(candidate.ErpId)
            && context.ExistingCompaniesByErpId.TryGetValue(candidate.ErpId, out var byErpId))
        {
            return byErpId;
        }

        if (!string.IsNullOrWhiteSpace(candidate.Name)
            && context.ExistingCompaniesByName.TryGetValue(candidate.Name, out var byName))
        {
            return byName;
        }

        if (!string.IsNullOrWhiteSpace(candidate.CrmId)
            && context.ExistingCompaniesByCrmId.TryGetValue(candidate.CrmId, out var byCrmId))
        {
            return byCrmId;
        }

        return null;
    }

    private static async Task<CompanyMigrationExecutionResult> CreateParspecCompanyAsync(
        ParspecMigratorConfig config,
        CompanyCandidate candidate,
        CompanyCreatePayload payload)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Post, "v1/companies")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"Create failed for {candidate.ErpId} ({candidate.Name}): HTTP {(int)response.StatusCode} {response.StatusCode}");
            Console.WriteLine(responseBody);

            return new CompanyMigrationExecutionResult
            {
                SourceErpId = candidate.ErpId,
                SourceName = candidate.Name,
                Status = "failed",
                Message = responseBody
            };
        }

        var createdCompany = JsonSerializer.Deserialize<ParspecCompany>(responseBody, ApiJsonOptions);

        return new CompanyMigrationExecutionResult
        {
            SourceErpId = candidate.ErpId,
            SourceName = candidate.Name,
            Status = "created",
            ParspecCompanyId = createdCompany?.Id,
            Message = responseBody
        };
    }

    private static async Task<ParspecCompany?> FindExistingParspecCompanyAsync(
        ParspecMigratorConfig config,
        CompanyCandidate candidate)
    {
        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var filters = new List<string>();
        if (!string.IsNullOrWhiteSpace(candidate.ErpId))
        {
            filters.Add($"erpId={Uri.EscapeDataString(candidate.ErpId)}");
        }

        if (!string.IsNullOrWhiteSpace(candidate.CrmId))
        {
            filters.Add($"crmId={Uri.EscapeDataString(candidate.CrmId)}");
        }

        if (!string.IsNullOrWhiteSpace(candidate.Name))
        {
            filters.Add($"name={Uri.EscapeDataString(candidate.Name)}");
        }

        foreach (var filter in filters.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            using var response = await client.GetAsync($"v1/companies?limit=5&{filter}");
            var body = await response.Content.ReadAsStringAsync();
            if (!response.IsSuccessStatusCode)
            {
                continue;
            }

            var payload = JsonSerializer.Deserialize<ParspecCompanyListResponse>(body, ApiJsonOptions);
            var existing = payload?.Results.FirstOrDefault(company =>
                (!string.IsNullOrWhiteSpace(candidate.ErpId) && string.Equals(company.ErpId, candidate.ErpId, StringComparison.OrdinalIgnoreCase))
                || (!string.IsNullOrWhiteSpace(candidate.CrmId) && string.Equals(company.CrmId, candidate.CrmId, StringComparison.OrdinalIgnoreCase))
                || (!string.IsNullOrWhiteSpace(candidate.Name) && string.Equals(company.Name, candidate.Name, StringComparison.OrdinalIgnoreCase)));

            if (existing is not null)
            {
                return existing;
            }
        }

        return null;
    }

    private static async Task PatchCompanyAddressAsync(
        ParspecMigratorConfig config,
        int companyId,
        CompanyAddress address)
    {
        if (!address.HasContent)
        {
            return;
        }

        var countryCode = NormalizeCountryCode(address.CountryCode) ?? InferCountryCode(address.StateOrRegionCode) ?? string.Empty;
        var payload = new CompanyV2PatchPayload
        {
            Address = new V2AddressPayload
            {
                AddressLine1 = NullIfWhiteSpace(address.AddressLine1) ?? string.Empty,
                AddressLine2 = NullIfWhiteSpace(address.AddressLine2) ?? string.Empty,
                City = NullIfWhiteSpace(address.City) ?? string.Empty,
                CountryCode = countryCode,
                PostalCode = NullIfWhiteSpace(address.PostalCode) ?? string.Empty,
                StateOrRegionCode = NormalizeParspecRegionCode(countryCode, address.StateOrRegionCode)
            }
        };

        using var client = new HttpClient
        {
            BaseAddress = new Uri(config.ParspecApiBaseUrl, UriKind.Absolute),
            Timeout = TimeSpan.FromSeconds(60)
        };

        client.DefaultRequestHeaders.Add("x-api-key", config.ParspecApiKey);

        var body = JsonSerializer.Serialize(payload, ApiJsonOptions);
        using var request = new HttpRequestMessage(HttpMethod.Patch, $"v2/companies/{companyId}")
        {
            Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
        };

        using var response = await client.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();
        if (!response.IsSuccessStatusCode)
        {
            Console.WriteLine($"Address patch failed for Parspec company {companyId}: HTTP {(int)response.StatusCode} {response.StatusCode}");
            Console.WriteLine(responseBody);
        }
    }

    private static UserMigrationReport BuildUserReport(IReadOnlyList<UserCandidate> users)
    {
        var activeOasisUsers = users.Count(user => user.OasisActive);
        var matchedAoUsers = users.Count(user => user.OasisActive && !string.IsNullOrWhiteSpace(user.AoUserId));
        var missingAoUsers = users.Count(user => user.OasisActive && string.IsNullOrWhiteSpace(user.AoUserId));
        var aoOnlyActiveUsers = users.Count(user => !user.OasisActive && user.AoIsActive == true);
        var usersReadyForPatch = users.Count(user =>
            user.OasisActive &&
            !string.IsNullOrWhiteSpace(user.CandidateParspecPatch.ParspecWritableFields.ErpId) &&
            !string.IsNullOrWhiteSpace(user.CandidateParspecPatch.ParspecWritableFields.CrmId));
        var usersWithUnresolvedPatchFields = users.Count(user =>
            user.OasisActive &&
            user.CandidateParspecPatch.UnresolvedFields.Count > 0);

        var territoryCounts = users
            .Where(user => user.OasisActive && !string.IsNullOrWhiteSpace(user.TerritoryId))
            .GroupBy(user => user.TerritoryId!, StringComparer.OrdinalIgnoreCase)
            .Select(group => new TerritorySummary(group.Key, group.Count()))
            .OrderByDescending(item => item.Count)
            .ThenBy(item => item.TerritoryId, StringComparer.OrdinalIgnoreCase)
            .ToList();

        var workgroupCounts = users
            .Where(user => user.OasisActive)
            .SelectMany(user => user.AoWorkgroups)
            .GroupBy(group => group, StringComparer.OrdinalIgnoreCase)
            .Select(group => new WorkgroupSummary(group.Key, group.Count()))
            .OrderByDescending(item => item.Count)
            .ThenBy(item => item.Workgroup, StringComparer.OrdinalIgnoreCase)
            .ToList();

        return new UserMigrationReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            Summary = new UserMigrationSummary
            {
                ActiveOasisUsers = activeOasisUsers,
                MatchedAoUsers = matchedAoUsers,
                MissingAoUsers = missingAoUsers,
                AoOnlyActiveUsers = aoOnlyActiveUsers,
                UsersReadyForPatch = usersReadyForPatch,
                UsersWithUnresolvedPatchFields = usersWithUnresolvedPatchFields
            },
            TerritoryCounts = territoryCounts,
            WorkgroupCounts = workgroupCounts,
            Users = users
        };
    }

    private static ParspecUserMatchReport BuildParspecUserMatchReport(
        IReadOnlyList<UserCandidate> sourceUsers,
        IReadOnlyList<ParspecUser> parspecUsers)
    {
        var activeSourceUsers = sourceUsers
            .Where(user => user.OasisActive)
            .ToList();

        var sourceByAoName = activeSourceUsers
            .Where(user => !string.IsNullOrWhiteSpace(user.AoName))
            .GroupBy(user => user.AoName!, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(group => group.Key, group => group.ToList(), StringComparer.OrdinalIgnoreCase);

        var matches = new List<ParspecUserMatch>();
        foreach (var parspecUser in parspecUsers.OrderBy(user => user.Name, StringComparer.OrdinalIgnoreCase))
        {
            sourceByAoName.TryGetValue(parspecUser.Name ?? string.Empty, out var candidates);
            candidates ??= new List<UserCandidate>();

            matches.Add(new ParspecUserMatch
            {
                ParspecUser = parspecUser,
                MatchType = candidates.Count switch
                {
                    0 => "unmatched",
                    1 => "exact-name",
                    _ => "ambiguous-name"
                },
                CandidateSourceUsers = candidates,
                RecommendedSourceUser = candidates.Count == 1 ? candidates[0] : null,
                PatchReady = candidates.Count == 1
                    && !string.IsNullOrWhiteSpace(candidates[0].CandidateParspecPatch.ParspecWritableFields.CrmId)
                    && !string.IsNullOrWhiteSpace(candidates[0].CandidateParspecPatch.ParspecWritableFields.ErpId)
                    && candidates[0].CandidateParspecPatch.UnresolvedFields.Count == 0
            });
        }

        return new ParspecUserMatchReport
        {
            GeneratedAtUtc = DateTime.UtcNow,
            Summary = new ParspecUserMatchSummary
            {
                ParspecUsersScanned = parspecUsers.Count,
                ExactNameMatches = matches.Count(match => string.Equals(match.MatchType, "exact-name", StringComparison.OrdinalIgnoreCase)),
                PatchReadyMatches = matches.Count(match => match.PatchReady),
                UnmatchedParspecUsers = matches.Count(match => string.Equals(match.MatchType, "unmatched", StringComparison.OrdinalIgnoreCase))
            },
            Matches = matches
        };
    }

    private static string? GetNullableString(SqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetValue(ordinal)?.ToString();
    }

    private static int? GetNullableInt(SqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : Convert.ToInt32(reader.GetValue(ordinal));
    }

    private static decimal? GetNullableDecimal(SqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : Convert.ToDecimal(reader.GetValue(ordinal));
    }

    private static DateTime? GetNullableDateTime(SqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetDateTime(ordinal);
    }

    private static bool? GetNullableBoolean(SqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetBoolean(ordinal);
    }

    private static IReadOnlyList<string> SplitSemicolonList(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            return Array.Empty<string>();
        }

        return raw
            .Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
    }
}

internal sealed record ParspecMigratorConfig
{
    public string OasisConnectionString { get; init; } =
        "Server=.\\ERPLINK;Database=OASIS_MACSII;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False";

    public string BusinessConnectionString { get; init; } =
        "Server=.\\ERPLINK;Database=MACSII_V2;Trusted_Connection=True;TrustServerCertificate=True;Encrypt=False";

    public string ParspecApiBaseUrl { get; init; } =
        "https://platform-sandbox.parspec.io/platform-api/api/";

    public string? ParspecApiKey { get; init; } =
        Environment.GetEnvironmentVariable("PARSPEC_API_KEY");

    public string OutputDirectory { get; init; } =
        Path.Combine(AppContext.BaseDirectory, "output");

    public IReadOnlyDictionary<string, int> LocationMappings { get; init; } =
        new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);

    public static ParspecMigratorConfig Load()
    {
        var appSettingsPath = Path.Combine(AppContext.BaseDirectory, "appsettings.json");
        if (!File.Exists(appSettingsPath))
        {
            return new ParspecMigratorConfig();
        }

        var json = File.ReadAllText(appSettingsPath);
        var loaded = JsonSerializer.Deserialize<ParspecMigratorConfig>(json);
        if (loaded is null)
        {
            return new ParspecMigratorConfig();
        }

        return loaded with
        {
            ParspecApiBaseUrl = Environment.GetEnvironmentVariable("PARSPEC_API_BASE_URL") ?? loaded.ParspecApiBaseUrl,
            ParspecApiKey = Environment.GetEnvironmentVariable("PARSPEC_API_KEY") ?? loaded.ParspecApiKey
        };
    }
}

internal sealed record UserMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public required UserMigrationSummary Summary { get; init; }
    public required IReadOnlyList<TerritorySummary> TerritoryCounts { get; init; }
    public required IReadOnlyList<WorkgroupSummary> WorkgroupCounts { get; init; }
    public required IReadOnlyList<UserCandidate> Users { get; init; }
}

internal sealed record UserMigrationSummary
{
    public int ActiveOasisUsers { get; init; }
    public int MatchedAoUsers { get; init; }
    public int MissingAoUsers { get; init; }
    public int AoOnlyActiveUsers { get; init; }
    public int UsersReadyForPatch { get; init; }
    public int UsersWithUnresolvedPatchFields { get; init; }
}

internal sealed record TerritorySummary(string TerritoryId, int Count);

internal sealed record WorkgroupSummary(string Workgroup, int Count);

internal sealed record UserCandidate
{
    public string? OasisUserId { get; init; }
    public string? FirstName { get; init; }
    public string? MiddleName { get; init; }
    public string? LastName { get; init; }
    public string? Initials { get; init; }
    public string? TerritoryId { get; init; }
    public bool OasisActive { get; init; }
    public string? AccountId { get; init; }
    public DateTime? LastLogin { get; init; }
    public DateTime? HireDate { get; init; }
    public DateTime? TerminationDate { get; init; }
    public string? AoUserId { get; init; }
    public string? AoErpUserId { get; init; }
    public bool? AoIsActive { get; init; }
    public string? AoName { get; init; }
    public IReadOnlyList<string> AoWorkgroups { get; init; } = Array.Empty<string>();
    public string? CandidateDisplayName { get; init; }
    public required UserPatchCandidate CandidateParspecPatch { get; init; }
}

internal sealed record UserPatchCandidate
{
    public required UserPatchPayload ParspecWritableFields { get; init; }
    public required IReadOnlyList<string> UnresolvedFields { get; init; }
}

internal sealed record UserPatchPayload
{
    public string? CrmId { get; init; }
    public int? DefaultLocation { get; init; }
    public string? ErpId { get; init; }
    public IReadOnlyList<int> LocationAccess { get; init; } = Array.Empty<int>();
}

internal sealed record LocationScanReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public int UsersWithMemberships { get; init; }
    public int ConfiguredMappings { get; init; }
    public required IReadOnlyList<SourceLocationCode> SourceCodes { get; init; }
    public required IReadOnlyList<LocationMembership> Memberships { get; init; }
}

internal sealed record SourceLocationCode
{
    public string SourceCode { get; init; } = string.Empty;
    public int UserCount { get; init; }
    public int? ConfiguredParspecLocationId { get; init; }
    public IReadOnlyList<string> SourceTables { get; init; } = Array.Empty<string>();
}

internal sealed record LocationMembership
{
    public string UserId { get; init; } = string.Empty;
    public string SourceCode { get; init; } = string.Empty;
    public string SourceTable { get; init; } = string.Empty;
}

internal sealed record ParspecUserListResponse
{
    public int Count { get; init; }
    public IReadOnlyList<ParspecUser> Results { get; init; } = Array.Empty<ParspecUser>();
}

internal sealed record ParspecUser
{
    public int Id { get; init; }
    public string? Name { get; init; }
    public string? Email { get; init; }
    public string? ErpId { get; init; }
    public int? DefaultLocation { get; init; }
    public IReadOnlyList<int> LocationAccess { get; init; } = Array.Empty<int>();
    public DateTimeOffset? LastActiveDateTime { get; init; }
}

internal sealed record ParspecUserMatchReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public required ParspecUserMatchSummary Summary { get; init; }
    public required IReadOnlyList<ParspecUserMatch> Matches { get; init; }
}

internal sealed record ParspecUserMatchSummary
{
    public int ParspecUsersScanned { get; init; }
    public int ExactNameMatches { get; init; }
    public int PatchReadyMatches { get; init; }
    public int UnmatchedParspecUsers { get; init; }
}

internal sealed record ParspecUserMatch
{
    public required ParspecUser ParspecUser { get; init; }
    public required string MatchType { get; init; }
    public required IReadOnlyList<UserCandidate> CandidateSourceUsers { get; init; }
    public UserCandidate? RecommendedSourceUser { get; init; }
    public bool PatchReady { get; init; }
}

internal sealed record CompanyMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public required CompanyMigrationSummary Summary { get; init; }
    public required IReadOnlyList<DestinationFieldCoverage> FieldCoverage { get; init; }
    public required IReadOnlyList<CompanyCandidate> Companies { get; init; }
}

internal sealed record CompanyMigrationSummary
{
    public int TotalCompanies { get; init; }
    public int TotalBaseFields { get; init; }
    public int ResolvedBaseFields { get; init; }
    public int UnresolvedBaseFields { get; init; }
    public int CompaniesWithCrmId { get; init; }
    public int CompaniesWithEmail { get; init; }
    public int CompaniesWithBillAddress { get; init; }
    public int CompaniesWithNotes { get; init; }
    public int CompaniesWithSoldAddress { get; init; }
    public int CompaniesWithShipAddress { get; init; }
    public int CompaniesWithParentReference { get; init; }
    public int CompaniesWithPhone { get; init; }
    public int CompaniesWithWebsite { get; init; }
}

internal sealed record DestinationFieldCoverage(
    string DestinationField,
    string Status,
    string Source,
    int TotalRows,
    int RowsWithValue,
    string Notes);

internal sealed record CompanyCandidate
{
    public string? ErpId { get; init; }
    public string? Name { get; init; }
    public string? BusinessType { get; init; }
    public string? CrmId { get; init; }
    public string? OutsideSalesCrmUserId { get; init; }
    public string? Email { get; init; }
    public string? Phone { get; init; }
    public string? Website { get; init; }
    public string? Fax { get; init; }
    public string? ParentErpId { get; init; }
    public string? ParentName { get; init; }
    public required CompanyAddress SoldToAddress { get; init; }
    public required CompanyAddress BillToAddress { get; init; }
    public required CompanyAddress ShipToAddress { get; init; }
    public string? OrderEntryNotes { get; init; }
    public string? InternalNotes { get; init; }
    public string? TermText { get; init; }
    public string? InvoiceTermText { get; init; }
    public string? TaxId { get; init; }
    public DateTime? LastUpdated { get; init; }
    public required CompanyFieldCoverage Coverage { get; init; }

    public bool HasNotesContent =>
        !string.IsNullOrWhiteSpace(OrderEntryNotes)
        || !string.IsNullOrWhiteSpace(InternalNotes)
        || !string.IsNullOrWhiteSpace(TermText)
        || !string.IsNullOrWhiteSpace(InvoiceTermText);
}

internal sealed record CompanyAddress
{
    public string? Name { get; init; }
    public string? AddressLine1 { get; init; }
    public string? AddressLine2 { get; init; }
    public string? City { get; init; }
    public string? StateOrRegionCode { get; init; }
    public string? PostalCode { get; init; }
    public string? CountryCode { get; init; }

    public bool HasContent =>
        !string.IsNullOrWhiteSpace(AddressLine1)
        || !string.IsNullOrWhiteSpace(AddressLine2)
        || !string.IsNullOrWhiteSpace(City)
        || !string.IsNullOrWhiteSpace(StateOrRegionCode)
        || !string.IsNullOrWhiteSpace(PostalCode)
        || !string.IsNullOrWhiteSpace(CountryCode)
        || !string.IsNullOrWhiteSpace(Name);
}

internal sealed record CompanyFieldCoverage
{
    public required IReadOnlyList<string> ResolvedFields { get; init; }
    public required IReadOnlyList<string> UnresolvedFields { get; init; }
    public required IReadOnlyList<string> RelatedObjects { get; init; }
}

internal sealed record CompanyCreatePayload
{
    public string? AddressLine1 { get; init; }
    public string? AddressLine2 { get; init; }
    public string? BusinessType { get; init; }
    public string? City { get; init; }
    public string? Country { get; init; }
    public string? CrmId { get; init; }
    public string? Duns { get; init; }
    public string? Email { get; init; }
    public string? ErpId { get; init; }
    public string? Name { get; init; }
    public string? Notes { get; init; }
    public int? OutsideSalesAgent { get; init; }
    public string? Phone { get; init; }
    public string? State { get; init; }
    public bool VisibleToAllLocations { get; init; }
    public IReadOnlyList<int>? VisibleToLocations { get; init; }
    public string? Website { get; init; }
    public string? ZipCode { get; init; }
}

internal sealed record ParspecCompanyListResponse
{
    public int Count { get; init; }
    public IReadOnlyList<ParspecCompany> Results { get; init; } = Array.Empty<ParspecCompany>();
}

internal sealed record ParspecCompany
{
    public int Id { get; init; }
    public string? AddressLine1 { get; init; }
    public string? AddressLine2 { get; init; }
    public string? City { get; init; }
    public string? Country { get; init; }
    public string? Name { get; init; }
    public string? ErpId { get; init; }
    public string? CrmId { get; init; }
    public string? BusinessType { get; init; }
    public string? Email { get; init; }
    public string? State { get; init; }
    public string? ZipCode { get; init; }
}

internal sealed record CompanyV2PatchPayload
{
    public V2AddressPayload? Address { get; init; }
}

internal sealed record V2AddressPayload
{
    public string AddressLine1 { get; init; } = string.Empty;
    public string AddressLine2 { get; init; } = string.Empty;
    public string City { get; init; } = string.Empty;
    public string CountryCode { get; init; } = string.Empty;
    public string PostalCode { get; init; } = string.Empty;
    public string? StateOrRegionCode { get; init; }
}

internal sealed record CompanyMigrationContext
{
    public required IReadOnlyList<int> LocationIds { get; init; }
    public required IReadOnlyList<UserCandidate> SourceUsers { get; init; }
    public required IReadOnlyList<ParspecUser> ParspecUsers { get; init; }
    public required Dictionary<string, ParspecCompany> ExistingCompaniesByErpId { get; init; }
    public required Dictionary<string, ParspecCompany> ExistingCompaniesByName { get; init; }
    public required Dictionary<string, ParspecCompany> ExistingCompaniesByCrmId { get; init; }
}

internal sealed record CompanyMigrationExecutionResult
{
    public string? SourceErpId { get; init; }
    public string? SourceName { get; init; }
    public string Status { get; init; } = string.Empty;
    public int? ParspecCompanyId { get; init; }
    public string? Message { get; init; }
}

internal sealed record CompanyBulkMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public int TotalCandidates { get; init; }
    public int CreatedCount { get; init; }
    public int UpdatedExistingCount { get; init; }
    public int FailedCount { get; init; }
    public required IReadOnlyList<CompanyMigrationExecutionResult> Results { get; init; }
}

internal sealed record ContactMigrationSummary
{
    public int TotalContacts { get; init; }
    public int TotalBaseFields { get; init; }
    public int ResolvedBaseFields { get; init; }
    public int UnresolvedBaseFields { get; init; }
    public int ContactsWithCompanyErpId { get; init; }
    public int ContactsWithCrmId { get; init; }
    public int ContactsWithEmail { get; init; }
    public int ContactsWithPhone { get; init; }
    public int ContactsWithJobTitle { get; init; }
    public int ContactsWithWorkAddress { get; init; }
    public int ContactsWithHomeAddress { get; init; }
    public int ContactsWithNotes { get; init; }
}

internal sealed record ContactMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public required ContactMigrationSummary Summary { get; init; }
    public required IReadOnlyList<DestinationFieldCoverage> FieldCoverage { get; init; }
    public required IReadOnlyList<ContactCandidate> Contacts { get; init; }
}

internal sealed record ContactCandidate
{
    public string? SourceContactId { get; init; }
    public string? ExternalId { get; init; }
    public string? OasisContactId { get; init; }
    public string? CrmId { get; init; }
    public string? CompanyErpId { get; init; }
    public string? CompanyName { get; init; }
    public string? FirstName { get; init; }
    public string? MiddleName { get; init; }
    public string? LastName { get; init; }
    public string? Department { get; init; }
    public string? JobTitle { get; init; }
    public string? Email { get; init; }
    public string? Phone { get; init; }
    public string? Extension { get; init; }
    public string? Mobile { get; init; }
    public string? Fax { get; init; }
    public required CompanyAddress WorkAddress { get; init; }
    public required CompanyAddress HomeAddress { get; init; }
    public DateTime? LastUpdated { get; init; }
}

internal sealed record ParspecContactListResponse
{
    public int Count { get; init; }
    public IReadOnlyList<ParspecContact> Results { get; init; } = Array.Empty<ParspecContact>();
}

internal sealed record ParspecContact
{
    public int Id { get; init; }
    public int Company { get; init; }
    public string? CrmId { get; init; }
    public string? Email { get; init; }
    public string? FirstName { get; init; }
    public string? LastName { get; init; }
}

internal sealed record ContactV2Payload
{
    public V2AddressPayload? Address { get; init; }
    public bool AddressInheritedFromCompany { get; init; }
    public int Company { get; init; }
    public string CrmId { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public string FirstName { get; init; } = string.Empty;
    public string JobTitle { get; init; } = string.Empty;
    public string LastName { get; init; } = string.Empty;
    public string Notes { get; init; } = string.Empty;
    public int? OutsideSalesAgent { get; init; }
    public string Phone { get; init; } = string.Empty;
}

internal sealed record ContactMigrationContext
{
    public required Dictionary<string, ParspecCompany> ExistingCompaniesByErpId { get; init; }
    public required Dictionary<string, ParspecContact> ExistingContactsByCrmId { get; init; }
    public required Dictionary<string, ParspecContact> ExistingContactsByNaturalKey { get; init; }
}

internal sealed record ContactMigrationExecutionResult
{
    public string? SourceContactId { get; init; }
    public string? SourceName { get; init; }
    public string Status { get; init; } = string.Empty;
    public int? ParspecContactId { get; init; }
    public string? Message { get; init; }
}

internal sealed record ContactBulkMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public int TotalCandidates { get; init; }
    public int CreatedCount { get; init; }
    public int UpdatedExistingCount { get; init; }
    public int FailedCount { get; init; }
    public required IReadOnlyList<ContactMigrationExecutionResult> Results { get; init; }
}

internal sealed record BomMigrationSummary
{
    public int TotalBoms { get; init; }
    public int TotalBaseFields { get; init; }
    public int ResolvedBaseFields { get; init; }
    public int UnresolvedBaseFields { get; init; }
    public int BomsWithCrmId { get; init; }
    public int BomsWithName { get; init; }
    public int BomsWithSalesAgent { get; init; }
    public int BomsWithPrimaryContact { get; init; }
    public int BomsWithSecondaryContact { get; init; }
}

internal sealed record BomMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public required BomMigrationSummary Summary { get; init; }
    public required IReadOnlyList<DestinationFieldCoverage> FieldCoverage { get; init; }
    public required IReadOnlyList<BomCandidate> Boms { get; init; }
}

internal sealed record BomCandidate
{
    public string? DbId { get; init; }
    public string? QuoteId { get; init; }
    public string? ProjectErpId { get; init; }
    public string? SourceProjectId { get; init; }
    public string? SourceBidId { get; init; }
    public string? CrmId { get; init; }
    public string? Name { get; init; }
    public string? SalesAgentAoUserId { get; init; }
    public string? PrimaryContactSourceId { get; init; }
    public string? PrimaryContactCompanyErpId { get; init; }
    public string? SecondaryContactSourceId { get; init; }
    public string? SecondaryContactCompanyErpId { get; init; }
    public string? ProjectManagerAoUserId { get; init; }
    public int LineCount { get; init; }
    public int LinesWithQuantity { get; init; }
    public int LinesWithSell { get; init; }
}

internal sealed record BomLineMigrationSummary
{
    public int TotalBomLines { get; init; }
    public int TotalBaseFields { get; init; }
    public int ResolvedBaseFields { get; init; }
    public int UnresolvedBaseFields { get; init; }
    public int LinesWithBomCrmId { get; init; }
    public int LinesWithErpLineId { get; init; }
    public int LinesWithManufacturerErpId { get; init; }
    public int LinesWithModelNumber { get; init; }
    public int LinesWithDescription { get; init; }
    public int LinesWithQuantity { get; init; }
    public int LinesWithExtendedSellAmount { get; init; }
    public int LinesWithUnitSellAmount { get; init; }
    public int LinesWithType { get; init; }
}

internal sealed record BomLineMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public required BomLineMigrationSummary Summary { get; init; }
    public required IReadOnlyList<DestinationFieldCoverage> FieldCoverage { get; init; }
    public required IReadOnlyList<BomLineCandidate> BomLines { get; init; }
}

internal sealed record BomLineCandidate
{
    public string? DbId { get; init; }
    public string? QuoteId { get; init; }
    public string? ProjectErpId { get; init; }
    public string? SourceProjectId { get; init; }
    public string? SourceBidId { get; init; }
    public string? BomCrmId { get; init; }
    public string? SourceLineId { get; init; }
    public string? ErpLineId { get; init; }
    public decimal? ItemNumber { get; init; }
    public string? LineUid { get; init; }
    public string? ManufacturerErpId { get; init; }
    public string? Type { get; init; }
    public string? ModelNumber { get; init; }
    public string? Description { get; init; }
    public decimal? Quantity { get; init; }
    public decimal? ExtendedSellAmount { get; init; }
    public decimal? UnitSellAmount { get; init; }
    public decimal? BookAmount { get; init; }
    public decimal? BaseAmount { get; init; }
    public decimal? OBaseAmount { get; init; }
    public decimal? Level1Amount { get; init; }
    public decimal? Level2Amount { get; init; }
    public decimal? Level3Amount { get; init; }
    public string? BidStatus { get; init; }
    public DateTime? UpdateDate { get; init; }
}

internal sealed record BomContactRef
{
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? Company { get; init; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? Contact { get; init; }
}

internal sealed record BomV2Payload
{
    public string CrmId { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public BomContactRef? PrimaryContact { get; init; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? SalesAgent { get; init; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public BomContactRef? SecondaryContact { get; init; }
}

internal sealed record ParspecBomListResponse
{
    public int Count { get; init; }
    public IReadOnlyList<ParspecBom> Results { get; init; } = Array.Empty<ParspecBom>();
}

internal sealed record ParspecBom
{
    public int Id { get; init; }
    public string? CrmId { get; init; }
    public string? Name { get; init; }
}

internal sealed record BomMigrationContext
{
    public required Dictionary<string, ParspecProject> ExistingProjectsByErpId { get; init; }
    public required Dictionary<int, Dictionary<string, ParspecOpportunity>> ExistingOpportunitiesByProjectId { get; init; }
    public required Dictionary<int, Dictionary<string, ParspecOpportunity>> ExistingOpportunitiesByProjectIdAndTitle { get; init; }
    public required IReadOnlyList<UserCandidate> SourceUsers { get; init; }
    public required IReadOnlyList<ParspecUser> ParspecUsers { get; init; }
    public required Dictionary<int, Dictionary<string, ParspecBom>> ExistingBomsByOpportunityId { get; init; }
    public required Dictionary<int, Dictionary<string, ParspecBom>> ExistingBomsByOpportunityIdAndName { get; init; }
    public required Dictionary<string, ParspecCompany> ExistingCompaniesByErpId { get; init; }
    public required Dictionary<string, ParspecContact> ExistingContactsByCrmId { get; init; }
    public required Dictionary<string, ContactCandidate> SourceContactsBySourceContactId { get; init; }
    public required Dictionary<string, IReadOnlyList<ProjectStakeholderCandidate>> StakeholdersByProjectErpId { get; init; }
}

internal sealed record BomMigrationExecutionResult
{
    public string? SourceProjectErpId { get; init; }
    public string? SourceQuoteId { get; init; }
    public string? SourceName { get; init; }
    public string Status { get; init; } = string.Empty;
    public int? ParspecBomId { get; init; }
    public string? Message { get; init; }
}

internal sealed record BomBulkMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public int Skip { get; init; }
    public int? Take { get; init; }
    public int TotalCandidates { get; init; }
    public int CreatedCount { get; init; }
    public int UpdatedExistingCount { get; init; }
    public int FailedCount { get; init; }
    public required IReadOnlyList<BomMigrationExecutionResult> Results { get; init; }
}

internal sealed record ManufacturerMigrationSummary
{
    public int TotalManufacturers { get; init; }
    public int TotalBaseFields { get; init; }
    public int ResolvedBaseFields { get; init; }
    public int UnresolvedBaseFields { get; init; }
    public int ManufacturersWithAoAccountId { get; init; }
    public int ManufacturersWithPhone { get; init; }
    public int ManufacturersWithWebsite { get; init; }
    public int ManufacturersWithFax { get; init; }
    public int ManufacturersWithMailAddress { get; init; }
    public int ManufacturersWithParentReference { get; init; }
}

internal sealed record ManufacturerMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public required ManufacturerMigrationSummary Summary { get; init; }
    public required IReadOnlyList<DestinationFieldCoverage> FieldCoverage { get; init; }
    public required IReadOnlyList<ManufacturerCandidate> Manufacturers { get; init; }
}

internal sealed record ManufacturerCandidate
{
    public string? ErpId { get; init; }
    public string? DisplayId { get; init; }
    public string? Name { get; init; }
    public string? CrmId { get; init; }
    public string? ParentCrmId { get; init; }
    public string? ParentName { get; init; }
    public string? Phone { get; init; }
    public string? Website { get; init; }
    public string? Fax { get; init; }
    public required CompanyAddress MailAddress { get; init; }
    public DateTime? LastUpdated { get; init; }
}

internal sealed record ParspecManufacturerListResponse
{
    public int Count { get; init; }
    public IReadOnlyList<ParspecManufacturer> Results { get; init; } = Array.Empty<ParspecManufacturer>();
}

internal sealed record ParspecManufacturer
{
    public int Id { get; init; }
    public string? ErpId { get; init; }
    public string? Name { get; init; }
}

internal sealed record ManufacturerV2Payload
{
    public IReadOnlyList<string> Abbreviations { get; init; } = Array.Empty<string>();
    public bool Active { get; init; }
    public required V2AddressPayload Address { get; init; }
    public bool EdiVendor { get; init; }
    public string ErpId { get; init; } = string.Empty;
    public bool Incentive { get; init; }
    public string Name { get; init; } = string.Empty;
    public int? ParspecManufacturerId { get; init; }
    public string PaymentTerms { get; init; } = string.Empty;
    public bool VisibleToAllLocations { get; init; }
    public IReadOnlyList<int>? VisibleToLocations { get; init; }
    public string Website { get; init; } = string.Empty;
}

internal sealed record ManufacturerMigrationContext
{
    public required Dictionary<string, ParspecManufacturer> ExistingManufacturersByErpId { get; init; }
    public required Dictionary<string, ParspecManufacturer> ExistingManufacturersByName { get; init; }
}

internal sealed record ManufacturerMigrationExecutionResult
{
    public string? SourceErpId { get; init; }
    public string? SourceName { get; init; }
    public string Status { get; init; } = string.Empty;
    public int? ParspecManufacturerId { get; init; }
    public string? Message { get; init; }
}

internal sealed record ManufacturerBulkMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public int TotalCandidates { get; init; }
    public int CreatedCount { get; init; }
    public int UpdatedExistingCount { get; init; }
    public int FailedCount { get; init; }
    public required IReadOnlyList<ManufacturerMigrationExecutionResult> Results { get; init; }
}

internal sealed record ProjectMigrationSummary
{
    public int TotalProjects { get; init; }
    public int TotalBaseFields { get; init; }
    public int ResolvedBaseFields { get; init; }
    public int UnresolvedBaseFields { get; init; }
    public int ProjectsWithErpId { get; init; }
    public int ProjectsWithCrmId { get; init; }
    public int ProjectsWithLocationMapping { get; init; }
    public int ProjectsWithOwner { get; init; }
    public int ProjectsWithQuoteDistributor { get; init; }
    public int ProjectsWithCustomerContact { get; init; }
    public int ProjectsWithMarketVertical { get; init; }
    public int ProjectsWithStakeholders { get; init; }
}

internal sealed record OpportunityMigrationSummary
{
    public int TotalOpportunities { get; init; }
    public int TotalBaseFields { get; init; }
    public int ResolvedBaseFields { get; init; }
    public int UnresolvedBaseFields { get; init; }
    public int OpportunitiesWithProjectErpId { get; init; }
    public int OpportunitiesWithCrmId { get; init; }
    public int OpportunitiesWithQuoteDueDate { get; init; }
    public int OpportunitiesWithSubmittalDueDate { get; init; }
    public int OpportunitiesWithQuoter { get; init; }
}

internal sealed record OpportunityMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public required OpportunityMigrationSummary Summary { get; init; }
    public required IReadOnlyList<DestinationFieldCoverage> FieldCoverage { get; init; }
    public required IReadOnlyList<OpportunityCandidate> Opportunities { get; init; }
}

internal sealed record OpportunityCandidate
{
    public string? DbId { get; init; }
    public string? ProjectErpId { get; init; }
    public string? SourceProjectId { get; init; }
    public string? QuoteId { get; init; }
    public string? CrmId { get; init; }
    public string? Title { get; init; }
    public string? BidStatus { get; init; }
    public DateTime? QuoteDueDate { get; init; }
    public DateTime? SubmittalDueDate { get; init; }
    public string? QuoterAoUserId { get; init; }
    public string? ProjectManagerAoUserId { get; init; }
    public decimal? EstimatedValue { get; init; }
    public decimal? QuoteLineCount { get; init; }
    public string? ProjectRank { get; init; }
    public string? ProjectName { get; init; }
}

internal sealed record ParspecOpportunityListResponse
{
    public int Count { get; init; }
    public IReadOnlyList<ParspecOpportunity> Results { get; init; } = Array.Empty<ParspecOpportunity>();
}

internal sealed record ParspecOpportunity
{
    public int Id { get; init; }
    public string? CrmId { get; init; }
    public string? Title { get; init; }
}

internal sealed record OpportunityV2Payload
{
    public string CrmId { get; init; } = string.Empty;
    public int? EstimatedValue { get; init; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? Pm { get; init; }
    public bool PmPerScope { get; init; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? QuoteDueDate { get; init; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public int? Quoter { get; init; }
    public bool QuoterPerScope { get; init; }
    public IReadOnlyList<object> Scopes { get; init; } = Array.Empty<object>();
    public string Stage { get; init; } = string.Empty;
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? SubmittalDueDate { get; init; }
    public string Title { get; init; } = string.Empty;
}

internal sealed record OpportunityMigrationContext
{
    public required Dictionary<string, ParspecProject> ExistingProjectsByErpId { get; init; }
    public required Dictionary<int, Dictionary<string, ParspecOpportunity>> ExistingOpportunitiesByProjectId { get; init; }
    public required Dictionary<int, Dictionary<string, ParspecOpportunity>> ExistingOpportunitiesByProjectIdAndTitle { get; init; }
    public required IReadOnlyList<UserCandidate> SourceUsers { get; init; }
    public required IReadOnlyList<ParspecUser> ParspecUsers { get; init; }
}

internal sealed record OpportunityMigrationExecutionResult
{
    public string? SourceProjectErpId { get; init; }
    public string? SourceQuoteId { get; init; }
    public string? SourceTitle { get; init; }
    public string Status { get; init; } = string.Empty;
    public int? ParspecOpportunityId { get; init; }
    public string? Message { get; init; }
}

internal sealed record OpportunityBulkMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public int Skip { get; init; }
    public int? Take { get; init; }
    public int TotalCandidates { get; init; }
    public int CreatedCount { get; init; }
    public int UpdatedExistingCount { get; init; }
    public int FailedCount { get; init; }
    public required IReadOnlyList<OpportunityMigrationExecutionResult> Results { get; init; }
}

internal sealed record ProjectMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public required ProjectMigrationSummary Summary { get; init; }
    public required IReadOnlyList<DestinationFieldCoverage> FieldCoverage { get; init; }
    public required IReadOnlyList<ProjectCandidate> Projects { get; init; }
}

internal sealed record ProjectCandidate
{
    public string? DbId { get; init; }
    public string? Name { get; init; }
    public string? ErpId { get; init; }
    public string? CrmId { get; init; }
    public string? QuoteNumber { get; init; }
    public string? QuoteDistributorId { get; init; }
    public string? CustomerContactId { get; init; }
    public string? ParentExternalId { get; init; }
    public string? ProjectRank { get; init; }
    public DateTime? BidDate { get; init; }
    public DateTime? CurrentBidDate { get; init; }
    public string? QuoteStatus { get; init; }
    public string? LocationCity { get; init; }
    public string? LocationState { get; init; }
    public DateTime? CreateDate { get; init; }
    public DateTime? UpdateDate { get; init; }
    public string? OwnerUserId { get; init; }
    public string? QuoterUserId { get; init; }
    public string? WorkGroup { get; init; }
    public int? LocationId { get; init; }
    public bool ShowOnBidBoard { get; init; }
    public decimal? Valuation { get; init; }
    public decimal? Sell { get; init; }
    public decimal? QuoteLineCount { get; init; }
    public string? ProjectCoordinatorUserId { get; init; }
    public string? ProjectStage { get; init; }
    public string? QuoteType { get; init; }
    public string? PhaseName { get; init; }
    public string? ProjectPOs { get; init; }
    public decimal? Ordered { get; init; }
    public decimal? Released { get; init; }
    public DateTime? OrderedDate { get; init; }
    public string? WinningDistributorId { get; init; }
    public string? WinningCustomerId { get; init; }
    public string? WinningContractorId { get; init; }
    public string? Followers { get; init; }
    public string? EngineerCompanyId { get; init; }
    public string? ArchitectCompanyId { get; init; }
    public decimal? Earnings { get; init; }
    public string? LockedBy { get; init; }
    public bool ManufacturerBts { get; init; }
    public bool BuySellBts { get; init; }
    public bool BuySellBti { get; init; }
    public int? SquareFootage { get; init; }
    public string? MarketVertical { get; init; }
}

internal sealed record ParspecProjectListResponse
{
    public int Count { get; init; }
    public IReadOnlyList<ParspecProject> Results { get; init; } = Array.Empty<ParspecProject>();
}

internal sealed record ParspecProject
{
    public int Id { get; init; }
    public string? ErpId { get; init; }
    public string? CrmId { get; init; }
    public int Location { get; init; }
    public string? Name { get; init; }
    public string? ProjectCode { get; init; }
}

internal sealed record ProjectStakeholderPayload
{
    public int? Company { get; init; }
    public int? Contact { get; init; }
}

internal sealed record ProjectStakeholderCandidate
{
    public string? ProjectErpId { get; init; }
    public string? AOProjectId { get; init; }
    public string? AOBidId { get; init; }
    public string? AccountCrmId { get; init; }
    public string? AccountErpId { get; init; }
    public string? ContactCrmId { get; init; }
    public string? ContactExternalId { get; init; }
    public string? AccountCategory { get; init; }
    public string? ActiveStatus { get; init; }
    public string? Role { get; init; }
}

internal sealed record ProjectV2Payload
{
    public required V2AddressPayload Address { get; init; }
    public string ConstructionScope { get; init; } = string.Empty;
    public string CrmId { get; init; } = string.Empty;
    public string ErpId { get; init; } = string.Empty;
    public int Location { get; init; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? MarketVertical { get; init; }
    public string Name { get; init; } = string.Empty;
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Owner { get; init; }
    public string ProjectCode { get; init; } = string.Empty;
    public IReadOnlyList<ProjectStakeholderPayload> ProjectStakeholders { get; init; } = Array.Empty<ProjectStakeholderPayload>();
    public int? SquareFootage { get; init; }
}

internal sealed record ProjectV1PatchPayload
{
    public int EstimatedValueCents { get; init; }
}

internal sealed record ProjectMigrationContext
{
    public required Dictionary<string, ParspecProject> ExistingProjectsByErpId { get; init; }
    public required Dictionary<string, ParspecProject> ExistingProjectsByCrmId { get; init; }
    public required Dictionary<string, ParspecProject> ExistingProjectsByNaturalKey { get; init; }
    public required Dictionary<string, ParspecProject> ExistingProjectsByLooseNaturalKey { get; init; }
    public required Dictionary<string, ParspecCompany> ExistingCompaniesByErpId { get; init; }
    public required Dictionary<string, ParspecCompany> ExistingCompaniesByCrmId { get; init; }
    public required Dictionary<string, ParspecContact> ExistingContactsByCrmId { get; init; }
    public required Dictionary<string, IReadOnlyList<ProjectStakeholderCandidate>> StakeholdersByProjectErpId { get; init; }
}

internal sealed record ProjectMigrationExecutionResult
{
    public string? SourceErpId { get; init; }
    public string? SourceName { get; init; }
    public string Status { get; init; } = string.Empty;
    public int? ParspecProjectId { get; init; }
    public string? Message { get; init; }
    public string? V1EnrichmentStatus { get; init; }
    public string? V1EnrichmentMessage { get; init; }
    public int? EstimatedValueCents { get; init; }
}

internal sealed record ProjectBulkMigrationReport
{
    public DateTime GeneratedAtUtc { get; init; }
    public int Skip { get; init; }
    public int? Take { get; init; }
    public int TotalCandidates { get; init; }
    public int CreatedCount { get; init; }
    public int UpdatedExistingCount { get; init; }
    public int FailedCount { get; init; }
    public int V1EnrichedCount { get; init; }
    public int V1EnrichmentFailedCount { get; init; }
    public required IReadOnlyList<ProjectMigrationExecutionResult> Results { get; init; }
}

internal sealed record ParspecV1PatchResult
{
    public bool IsSuccess { get; init; }
    public string? ResponseBody { get; init; }
}
