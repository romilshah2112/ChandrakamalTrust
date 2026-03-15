using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Invoices;
using OptimaHealthcare.Contracts.Masters;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlInvoiceService : IInvoiceService
{
    private readonly string _connectionString;

    public SqlInvoiceService(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found. Use ConnectionStrings:HealthCareContext or DefaultConnection.");
    }

    public async Task<IReadOnlyList<PatientInvoiceDto>> ListAsync(CancellationToken cancellationToken)
    {
        const string masterSql = @"
SELECT
    im.[lInvoiceMasterId],
    im.[InvoiceNumber],
    im.[lPatientDataId],
    ISNULL(pd.[FirstName], '') + CASE WHEN pd.[LastName] IS NULL OR pd.[LastName] = '' THEN '' ELSE ' ' + pd.[LastName] END AS [PatientName],
    pd.[BirthDate] AS [PatientBirthDate],
    ISNULL(pd.[Gender], '') AS [PatientGender],
    im.[lDoctorProfileId],
    ISNULL(dp.[DoctorName], '') AS [DoctorName],
    ISNULL(dp.[DoctorDegree], '') AS [DoctorDegree],
    ISNULL(dp.[DoctorStream], '') AS [DoctorStream],
    im.[lClinicId],
    ISNULL(c.[ClinicName], '') AS [ClinicName],
    ISNULL(c.[Address], '') AS [ClinicAddress],
    ISNULL(CONVERT(varchar(32), c.[Phone]), '') AS [ClinicPhone],
    im.[InvoiceDate],
    ISNULL(im.[Comments], '') AS [Comments],
    im.[lEnterById],
    im.[EnteredOn],
    im.[IsActive]
FROM [InvoiceMaster] im
LEFT JOIN [patientdata] pd ON pd.[lPatientDataId] = im.[lPatientDataId]
LEFT JOIN [DoctorProfile] dp ON dp.[lDoctorProfileId] = im.[lDoctorProfileId]
LEFT JOIN [Clinic] c ON c.[lClinicId] = im.[lClinicId]
WHERE im.[IsActive] = 1
ORDER BY im.[InvoiceDate] DESC, im.[lInvoiceMasterId] DESC";

        const string detailSql = @"
SELECT
    id.[InvoiceDetailId],
    id.[lInvoiceMasterId],
    id.[lInvoiceTypeId],
    ISNULL(it.[InvType], '') AS [InvoiceTypeName],
    id.[InvoiceAmount],
    id.[Deduction]
FROM [InvoiceDetail] id
LEFT JOIN [InvoiceType] it ON it.[lInvoiceTypeId] = id.[lInvoiceTypeId]
ORDER BY id.[InvoiceDetailId]";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);

        var invoices = new List<PatientInvoiceDto>();
        var map = new Dictionary<int, List<InvoiceLineDto>>();

        await using (var masterCmd = new SqlCommand(masterSql, con))
        await using (var reader = await masterCmd.ExecuteReaderAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                var id = SafeInt(reader["lInvoiceMasterId"]);
                map[id] = [];
                invoices.Add(new PatientInvoiceDto
                {
                    InvoiceMasterId = id,
                    InvoiceNumber = reader["InvoiceNumber"]?.ToString() ?? string.Empty,
                    PatientDataId = SafeInt(reader["lPatientDataId"]),
                    PatientName = reader["PatientName"]?.ToString() ?? string.Empty,
                    PatientBirthDate = SafeDateOnly(reader["PatientBirthDate"]),
                    PatientGender = reader["PatientGender"]?.ToString() ?? string.Empty,
                    DoctorProfileId = SafeInt(reader["lDoctorProfileId"]),
                    DoctorName = reader["DoctorName"]?.ToString() ?? string.Empty,
                    DoctorDegree = reader["DoctorDegree"]?.ToString() ?? string.Empty,
                    DoctorStream = reader["DoctorStream"]?.ToString() ?? string.Empty,
                    ClinicId = SafeInt(reader["lClinicId"]),
                    ClinicName = reader["ClinicName"]?.ToString() ?? string.Empty,
                    ClinicAddress = reader["ClinicAddress"]?.ToString() ?? string.Empty,
                    ClinicPhone = reader["ClinicPhone"]?.ToString() ?? string.Empty,
                    InvoiceDate = SafeDateTime(reader["InvoiceDate"]),
                    Comments = reader["Comments"]?.ToString() ?? string.Empty,
                    EnteredById = SafeInt(reader["lEnterById"]),
                    EnteredOn = SafeDateTime(reader["EnteredOn"]),
                    IsActive = SafeBool(reader["IsActive"]),
                });
            }
        }

        await using (var detailCmd = new SqlCommand(detailSql, con))
        await using (var reader = await detailCmd.ExecuteReaderAsync(cancellationToken))
        {
            while (await reader.ReadAsync(cancellationToken))
            {
                var masterId = SafeInt(reader["lInvoiceMasterId"]);
                if (!map.TryGetValue(masterId, out var lines))
                {
                    continue;
                }

                lines.Add(new InvoiceLineDto
                {
                    InvoiceDetailId = SafeInt(reader["InvoiceDetailId"]),
                    InvoiceTypeId = SafeInt(reader["lInvoiceTypeId"]),
                    InvoiceTypeName = reader["InvoiceTypeName"]?.ToString() ?? string.Empty,
                    InvoiceAmount = SafeDouble(reader["InvoiceAmount"]),
                    Deduction = SafeDouble(reader["Deduction"])
                });
            }
        }

        return invoices
            .Select(invoice => new PatientInvoiceDto
            {
                InvoiceMasterId = invoice.InvoiceMasterId,
                InvoiceNumber = invoice.InvoiceNumber,
                PatientDataId = invoice.PatientDataId,
                PatientName = invoice.PatientName,
                PatientBirthDate = invoice.PatientBirthDate,
                PatientGender = invoice.PatientGender,
                DoctorProfileId = invoice.DoctorProfileId,
                DoctorName = invoice.DoctorName,
                DoctorDegree = invoice.DoctorDegree,
                DoctorStream = invoice.DoctorStream,
                ClinicId = invoice.ClinicId,
                ClinicName = invoice.ClinicName,
                ClinicAddress = invoice.ClinicAddress,
                ClinicPhone = invoice.ClinicPhone,
                InvoiceDate = invoice.InvoiceDate,
                Comments = invoice.Comments,
                EnteredById = invoice.EnteredById,
                EnteredOn = invoice.EnteredOn,
                IsActive = invoice.IsActive,
                Lines = map[invoice.InvoiceMasterId]
            })
            .ToList();
    }

    public async Task<string> GetNextInvoiceNumberAsync(CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        return await GetNextInvoiceNumberAsync(con, null, cancellationToken);
    }

    public async Task<IReadOnlyList<InvoiceTypeDto>> ListInvoiceTypesAsync(CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT [lInvoiceTypeId], [InvType], ISNULL([Description], '') AS [Description], ISNULL([Charges], 0) AS [Charges], [IsActive]
FROM [InvoiceType]
WHERE [IsActive] = 1
ORDER BY [InvType]";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        var list = new List<InvoiceTypeDto>();
        while (await reader.ReadAsync(cancellationToken))
        {
            list.Add(new InvoiceTypeDto
            {
                InvoiceTypeId = SafeInt(reader["lInvoiceTypeId"]),
                InvoiceTypeName = reader["InvType"]?.ToString() ?? string.Empty,
                Description = reader["Description"]?.ToString() ?? string.Empty,
                Charges = SafeDouble(reader["Charges"]),
                IsActive = SafeBool(reader["IsActive"])
            });
        }

        return list;
    }

    public async Task<int> CreateAsync(SavePatientInvoiceRequest request, int enteredById, CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var tx = await con.BeginTransactionAsync(cancellationToken);

        var invoiceNumber = await GetNextInvoiceNumberAsync(con, (SqlTransaction)tx, cancellationToken);

        const string masterSql = @"
INSERT INTO [InvoiceMaster]
    ([InvoiceNumber], [lPatientDataId], [lDoctorProfileId], [lClinicId], [InvoiceDate], [Comments], [lEnterById], [EnteredOn], [IsActive])
OUTPUT INSERTED.[lInvoiceMasterId]
VALUES
    (@invoiceNumber, @patientDataId, @doctorProfileId, @clinicId, @invoiceDate, @comments, @enteredById, @enteredOn, @isActive)";

        await using var masterCmd = new SqlCommand(masterSql, con, (SqlTransaction)tx);
        masterCmd.Parameters.AddWithValue("@invoiceNumber", invoiceNumber);
        BindMaster(masterCmd, request, enteredById);
        var insertedId = Convert.ToInt32(await masterCmd.ExecuteScalarAsync(cancellationToken));

        await InsertDetailsAsync(con, (SqlTransaction)tx, insertedId, request.Lines, cancellationToken);
        await tx.CommitAsync(cancellationToken);
        return insertedId;
    }

    public async Task UpdateAsync(int invoiceMasterId, SavePatientInvoiceRequest request, int enteredById, CancellationToken cancellationToken)
    {
        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var tx = await con.BeginTransactionAsync(cancellationToken);

        const string updateMasterSql = @"
UPDATE [InvoiceMaster]
SET [lPatientDataId] = @patientDataId,
    [lDoctorProfileId] = @doctorProfileId,
    [lClinicId] = @clinicId,
    [InvoiceDate] = @invoiceDate,
    [Comments] = @comments,
    [lEnterById] = @enteredById
WHERE [lInvoiceMasterId] = @id";

        await using (var masterCmd = new SqlCommand(updateMasterSql, con, (SqlTransaction)tx))
        {
            BindMaster(masterCmd, request, enteredById);
            masterCmd.Parameters.AddWithValue("@id", invoiceMasterId);
            await masterCmd.ExecuteNonQueryAsync(cancellationToken);
        }

        await using (var deleteCmd = new SqlCommand("DELETE FROM [InvoiceDetail] WHERE [lInvoiceMasterId] = @id", con, (SqlTransaction)tx))
        {
            deleteCmd.Parameters.AddWithValue("@id", invoiceMasterId);
            await deleteCmd.ExecuteNonQueryAsync(cancellationToken);
        }

        await InsertDetailsAsync(con, (SqlTransaction)tx, invoiceMasterId, request.Lines, cancellationToken);
        await tx.CommitAsync(cancellationToken);
    }

    public async Task DeleteAsync(int invoiceMasterId, CancellationToken cancellationToken)
    {
        const string sql = @"UPDATE [InvoiceMaster] SET [IsActive] = 0 WHERE [lInvoiceMasterId] = @id";

        await using var con = new SqlConnection(_connectionString);
        await con.OpenAsync(cancellationToken);
        await using var cmd = new SqlCommand(sql, con);
        cmd.Parameters.AddWithValue("@id", invoiceMasterId);
        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    private static void BindMaster(SqlCommand cmd, SavePatientInvoiceRequest request, int enteredById)
    {
        cmd.Parameters.AddWithValue("@patientDataId", request.PatientDataId);
        cmd.Parameters.AddWithValue("@doctorProfileId", request.DoctorProfileId);
        cmd.Parameters.AddWithValue("@clinicId", request.ClinicId);
        cmd.Parameters.AddWithValue("@invoiceDate", request.InvoiceDate);
        cmd.Parameters.AddWithValue("@comments", (object?)request.Comments ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@enteredById", enteredById);
        if (!cmd.Parameters.Contains("@enteredOn"))
        {
            cmd.Parameters.AddWithValue("@enteredOn", DateTime.UtcNow);
        }
        if (!cmd.Parameters.Contains("@isActive"))
        {
            cmd.Parameters.AddWithValue("@isActive", true);
        }
    }

    private static async Task InsertDetailsAsync(
        SqlConnection con,
        SqlTransaction tx,
        int invoiceMasterId,
        IReadOnlyList<SavePatientInvoiceLineRequest> lines,
        CancellationToken cancellationToken)
    {
        const string detailSql = @"
INSERT INTO [InvoiceDetail]
    ([lInvoiceMasterId], [lInvoiceTypeId], [InvoiceAmount], [Deduction])
VALUES
    (@invoiceMasterId, @invoiceTypeId, @invoiceAmount, @deduction)";

        foreach (var line in lines)
        {
            await using var detailCmd = new SqlCommand(detailSql, con, tx);
            detailCmd.Parameters.AddWithValue("@invoiceMasterId", invoiceMasterId);
            detailCmd.Parameters.AddWithValue("@invoiceTypeId", line.InvoiceTypeId);
            detailCmd.Parameters.AddWithValue("@invoiceAmount", line.InvoiceAmount);
            detailCmd.Parameters.AddWithValue("@deduction", line.Deduction);
            await detailCmd.ExecuteNonQueryAsync(cancellationToken);
        }
    }

    private static async Task<string> GetNextInvoiceNumberAsync(
        SqlConnection con,
        SqlTransaction? tx,
        CancellationToken cancellationToken)
    {
        const string sql = @"
SELECT ISNULL(MAX(TRY_CONVERT(int, SUBSTRING([InvoiceNumber], 6, LEN([InvoiceNumber]) - 5))), 0)
FROM [InvoiceMaster]
WHERE [InvoiceNumber] LIKE 'PHCC-%'";

        await using var cmd = tx is null
            ? new SqlCommand(sql, con)
            : new SqlCommand(sql, con, tx);
        var currentMax = Convert.ToInt32(await cmd.ExecuteScalarAsync(cancellationToken));
        return $"PHCC-{(currentMax + 1).ToString("0000")}";
    }

    private static int SafeInt(object value) => value is DBNull ? 0 : Convert.ToInt32(value);
    private static double SafeDouble(object value) => value is DBNull ? 0d : Convert.ToDouble(value);
    private static bool SafeBool(object value) => value is not DBNull && Convert.ToBoolean(value);
    private static DateTime SafeDateTime(object value) => value is DBNull ? DateTime.MinValue : Convert.ToDateTime(value);
    private static DateOnly? SafeDateOnly(object value) => value is DBNull ? null : DateOnly.FromDateTime(Convert.ToDateTime(value));
}
