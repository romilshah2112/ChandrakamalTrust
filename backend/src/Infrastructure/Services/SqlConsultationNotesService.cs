using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Consultation;

namespace OptimaHealthcare.Infrastructure.Services;

public sealed class SqlConsultationNotesService : IConsultationNotesService
{
    private readonly string _connectionString;
    private readonly ILLMService _llmService;
    private readonly IMasterDataService _masterDataService;
    private readonly ILogger<SqlConsultationNotesService> _logger;

    public SqlConsultationNotesService(
        IConfiguration configuration,
        ILLMService llmService,
        IMasterDataService masterDataService,
        ILogger<SqlConsultationNotesService> logger)
    {
        _connectionString = configuration.GetConnectionString("HealthCareContext")
            ?? configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string not found.");
        _llmService = llmService;
        _masterDataService = masterDataService;
        _logger = logger;
    }

    public async Task SaveConsultationNotesAsync(SaveConsultationNotesRequest request, int enteredByAppUserId, CancellationToken cancellationToken = default)
    {
        if (request.PatientDataId <= 0)
        {
            throw new ArgumentException("PatientDataId is required.", nameof(request));
        }
        if (string.IsNullOrWhiteSpace(request.Transcript))
        {
            throw new ArgumentException("Transcript cannot be empty.", nameof(request));
        }

        var notes = await _llmService.ExtractConsultationNotesAsync(request.Transcript, cancellationToken);
        var doctorProfileId = await _masterDataService.GetDoctorProfileIdByAppUserIdAsync(enteredByAppUserId, cancellationToken);
        var consultationDate = DateTime.UtcNow;

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        using var transaction = connection.BeginTransaction();

        try
        {
            if (!string.IsNullOrWhiteSpace(notes.Complaint) || !string.IsNullOrWhiteSpace(notes.Symptoms))
            {
                const string complaintSql = @"
INSERT INTO [PatientComplaint] ([lPatientDataId], [Complaint], [Symptoms], [ConsultationDate], [lDoctorProfileId], [lEnteredById], [InsertedOn])
VALUES (@patientDataId, @complaint, @symptoms, @consultationDate, @doctorProfileId, @enteredById, @insertedOn)";

                await using (var cmd = new SqlCommand(complaintSql, connection, transaction))
                {
                    cmd.Parameters.AddWithValue("@patientDataId", request.PatientDataId);
                    cmd.Parameters.AddWithValue("@complaint", notes.Complaint);
                    cmd.Parameters.AddWithValue("@symptoms", notes.Symptoms);
                    cmd.Parameters.AddWithValue("@consultationDate", consultationDate);
                    cmd.Parameters.AddWithValue("@doctorProfileId", (object?)doctorProfileId ?? DBNull.Value);
                    cmd.Parameters.AddWithValue("@enteredById", enteredByAppUserId);
                    cmd.Parameters.AddWithValue("@insertedOn", consultationDate);
                    await cmd.ExecuteNonQueryAsync(cancellationToken);
                }
                _logger.LogInformation("Saved PatientComplaint for patient {PatientDataId}", request.PatientDataId);
            }

            if (!string.IsNullOrWhiteSpace(notes.MedicalHistory))
            {
                const string historySql = @"
INSERT INTO [PatientMedicalHistory] ([lPatientDataId], [HistoryText], [RecordedDate], [lEnteredById], [InsertedOn])
VALUES (@patientDataId, @historyText, @recordedDate, @enteredById, @insertedOn)";

                await using (var cmd = new SqlCommand(historySql, connection, transaction))
                {
                    cmd.Parameters.AddWithValue("@patientDataId", request.PatientDataId);
                    cmd.Parameters.AddWithValue("@historyText", notes.MedicalHistory);
                    cmd.Parameters.AddWithValue("@recordedDate", consultationDate);
                    cmd.Parameters.AddWithValue("@enteredById", enteredByAppUserId);
                    cmd.Parameters.AddWithValue("@insertedOn", consultationDate);
                    await cmd.ExecuteNonQueryAsync(cancellationToken);
                }
                _logger.LogInformation("Saved PatientMedicalHistory for patient {PatientDataId}", request.PatientDataId);
            }

            transaction.Commit();
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync(cancellationToken);
            _logger.LogError(ex, "Failed to save consultation notes for patient {PatientDataId}", request.PatientDataId);
            throw;
        }
    }
}
