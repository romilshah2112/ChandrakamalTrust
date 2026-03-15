using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using OptimaHealthcare.Api.Security;
using OptimaHealthcare.Application.Abstractions;
using OptimaHealthcare.Contracts.Invoices;
using OptimaHealthcare.Contracts.Masters;

namespace OptimaHealthcare.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/v1/invoices")]
public sealed class InvoicesController : ControllerBase
{
    private static readonly string[] AllowedRoles = ["admin", "doctor", "receptionist"];
    private readonly IInvoiceService _invoiceService;

    public InvoicesController(IInvoiceService invoiceService)
    {
        _invoiceService = invoiceService;
    }

    [HttpGet]
    [ProducesResponseType(typeof(IReadOnlyList<PatientInvoiceDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PatientInvoiceDto>>> List(CancellationToken cancellationToken)
    {
        if (!CanManageInvoices())
        {
            return Forbid();
        }

        return Ok(await _invoiceService.ListAsync(cancellationToken));
    }

    [HttpGet("next-number")]
    [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
    public async Task<ActionResult> NextNumber(CancellationToken cancellationToken)
    {
        if (!CanManageInvoices())
        {
            return Forbid();
        }

        return Ok(new { invoiceNumber = await _invoiceService.GetNextInvoiceNumberAsync(cancellationToken) });
    }

    [HttpGet("lookups/invoice-types")]
    [ProducesResponseType(typeof(IReadOnlyList<InvoiceTypeDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<InvoiceTypeDto>>> InvoiceTypes(CancellationToken cancellationToken)
    {
        if (!CanManageInvoices())
        {
            return Forbid();
        }

        return Ok(await _invoiceService.ListInvoiceTypesAsync(cancellationToken));
    }

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> Create([FromBody] SavePatientInvoiceRequest request, CancellationToken cancellationToken)
    {
        if (!CanManageInvoices())
        {
            return Forbid();
        }

        if (!Validate(request, out var error))
        {
            return BadRequest(error);
        }

        var id = await _invoiceService.CreateAsync(request, User.GetAppUserId(), cancellationToken);
        return StatusCode(StatusCodes.Status201Created, new { invoiceMasterId = id });
    }

    [HttpPut("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult> Update(int id, [FromBody] SavePatientInvoiceRequest request, CancellationToken cancellationToken)
    {
        if (!CanManageInvoices())
        {
            return Forbid();
        }

        if (!Validate(request, out var error))
        {
            return BadRequest(error);
        }

        await _invoiceService.UpdateAsync(id, request, User.GetAppUserId(), cancellationToken);
        return NoContent();
    }

    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<ActionResult> Delete(int id, CancellationToken cancellationToken)
    {
        if (!CanManageInvoices())
        {
            return Forbid();
        }

        await _invoiceService.DeleteAsync(id, cancellationToken);
        return NoContent();
    }

    private bool CanManageInvoices()
    {
        var role = User.GetRoleName();
        return AllowedRoles.Any(allowed => role.Contains(allowed, StringComparison.OrdinalIgnoreCase));
    }

    private static bool Validate(SavePatientInvoiceRequest request, out string error)
    {
        if (request.PatientDataId <= 0)
        {
            error = "PatientDataId is required.";
            return false;
        }
        if (request.DoctorProfileId <= 0)
        {
            error = "DoctorProfileId is required.";
            return false;
        }
        if (request.ClinicId <= 0)
        {
            error = "ClinicId is required.";
            return false;
        }
        if (request.Lines.Count == 0)
        {
            error = "At least one invoice item is required.";
            return false;
        }
        if (request.Lines.Any(line => line.InvoiceTypeId <= 0))
        {
            error = "InvoiceTypeId is required for all items.";
            return false;
        }

        error = string.Empty;
        return true;
    }
}
