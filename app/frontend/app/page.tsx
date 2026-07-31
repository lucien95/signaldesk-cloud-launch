"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

import {
  api,
  ApiError,
  type AvailabilitySlot,
  type Booking,
  type BookingStatus,
  type ServiceOption,
} from "@/lib/api";
import {
  bookingReference,
  businessDate,
  formatDateTime,
  formatTime,
  nextBusinessDate,
  statusLabel,
} from "@/lib/format";

type Workspace = "book" | "operations";
type HealthState = "checking" | "ready" | "unavailable";

interface FormState {
  customerName: string;
  customerEmail: string;
  service: string;
  date: string;
  scheduledAt: string;
}

const initialForm: FormState = {
  customerName: "",
  customerEmail: "",
  service: "",
  date: "",
  scheduledAt: "",
};

function ErrorNotice({ message, requestId }: { message: string; requestId?: string | null }) {
  return (
    <div className="notice notice-error" role="alert">
      <strong>We couldn&apos;t complete that action.</strong>
      <span>{message}</span>
      {requestId ? <small>Request ID: {requestId}</small> : null}
    </div>
  );
}

function StatusPill({ status }: { status: BookingStatus }) {
  return <span className={`status-pill status-${status}`}>{statusLabel(status)}</span>;
}

export default function Home() {
  const [workspace, setWorkspace] = useState<Workspace>("book");
  const [health, setHealth] = useState<HealthState>("checking");
  const [services, setServices] = useState<ServiceOption[]>([]);
  const [servicesError, setServicesError] = useState<string | null>(null);
  const [form, setForm] = useState<FormState>(initialForm);
  const [minimumBookingDate, setMinimumBookingDate] = useState("");
  const [slots, setSlots] = useState<AvailabilitySlot[]>([]);
  const [slotsLoading, setSlotsLoading] = useState(true);
  const [slotsError, setSlotsError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<{ message: string; requestId?: string | null } | null>(
    null,
  );
  const [confirmation, setConfirmation] = useState<{ booking: Booking; requestId: string | null } | null>(
    null,
  );
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [bookingsLoading, setBookingsLoading] = useState(false);
  const [bookingsError, setBookingsError] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<BookingStatus | "all">("all");
  const [search, setSearch] = useState("");
  const [updatingId, setUpdatingId] = useState<string | null>(null);
  const [operationNotice, setOperationNotice] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    const defaultDate = nextBusinessDate();
    Promise.allSettled([api.health(), api.services(), api.availability(defaultDate)]).then(
      ([healthResult, servicesResult, availabilityResult]) => {
        if (!active) return;
        setMinimumBookingDate(businessDate());
        setForm((current) => ({ ...current, date: defaultDate }));
        setHealth(healthResult.status === "fulfilled" ? "ready" : "unavailable");
        if (servicesResult.status === "fulfilled") {
          setServices(servicesResult.value.data);
          setForm((current) => ({
            ...current,
            service: current.service || servicesResult.value.data[0]?.name || "",
          }));
        } else {
          setServicesError("The service catalog is temporarily unavailable.");
        }
        if (availabilityResult.status === "fulfilled") {
          setSlots(availabilityResult.value.data.slots);
        } else {
          setSlotsError("Availability could not be loaded.");
        }
        setSlotsLoading(false);
      },
    );
    return () => {
      active = false;
    };
  }, []);

  async function loadAvailability(date: string) {
    setSlotsLoading(true);
    setSlotsError(null);
    try {
      const { data } = await api.availability(date);
      setSlots(data.slots);
    } catch (error) {
      setSlots([]);
      setSlotsError(error instanceof Error ? error.message : "Availability could not be loaded.");
    } finally {
      setSlotsLoading(false);
    }
  }

  const loadBookings = useCallback(async () => {
    setBookingsLoading(true);
    setBookingsError(null);
    setOperationNotice(null);
    try {
      const { data } = await api.listBookings(statusFilter, search);
      setBookings(data);
    } catch (error) {
      setBookingsError(error instanceof Error ? error.message : "Bookings could not be loaded.");
    } finally {
      setBookingsLoading(false);
    }
  }, [search, statusFilter]);

  const selectedService = services.find((service) => service.name === form.service);
  const availableSlots = slots.filter((slot) => slot.available);
  const bookingCounts = useMemo(
    () => ({
      confirmed: bookings.filter((booking) => booking.status === "confirmed").length,
      completed: bookings.filter((booking) => booking.status === "completed").length,
      cancelled: bookings.filter((booking) => booking.status === "cancelled").length,
    }),
    [bookings],
  );

  async function submitBooking(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitError(null);
    if (!form.scheduledAt) {
      setSubmitError({ message: "Choose one of the available appointment times." });
      return;
    }

    setSubmitting(true);
    try {
      const result = await api.createBooking({
        customer_name: form.customerName,
        customer_email: form.customerEmail,
        service: form.service,
        scheduled_at: form.scheduledAt,
      });
      const resetDate = nextBusinessDate();
      setConfirmation({ booking: result.data, requestId: result.requestId });
      setForm((current) => ({
        ...initialForm,
        service: current.service,
        date: resetDate,
      }));
      setBookings((current) => [...current, result.data]);
      void loadAvailability(resetDate);
    } catch (error) {
      const apiError = error instanceof ApiError ? error : null;
      setSubmitError({
        message: error instanceof Error ? error.message : "The booking could not be created.",
        requestId: apiError?.requestId,
      });
      if (apiError?.status === 409) {
        const availability = await api.availability(form.date).catch(() => null);
        if (availability) setSlots(availability.data.slots);
      }
    } finally {
      setSubmitting(false);
    }
  }

  async function updateBookingStatus(booking: Booking, status: BookingStatus) {
    const action = status === "completed" ? "complete" : "cancel";
    if (!window.confirm(`Are you sure you want to ${action} ${bookingReference(booking.id)}?`)) {
      return;
    }

    setUpdatingId(booking.id);
    setBookingsError(null);
    setOperationNotice(null);
    try {
      const { data, requestId } = await api.updateStatus(booking.id, status);
      setBookings((current) => current.map((item) => (item.id === data.id ? data : item)));
      setOperationNotice(
        `${bookingReference(data.id)} is now ${data.status}. Request ID: ${requestId ?? "not returned"}`,
      );
    } catch (error) {
      setBookingsError(error instanceof Error ? error.message : "The status could not be updated.");
    } finally {
      setUpdatingId(null);
    }
  }

  function chooseWorkspace(next: Workspace) {
    setWorkspace(next);
    if (next === "operations") void loadBookings();
    document.getElementById("workspace")?.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  return (
    <main>
      <header className="site-header">
        <a className="brand" href="#top" aria-label="SignalDesk home">
          <span className="brand-mark" aria-hidden="true">
            S
          </span>
          <span>
            <strong>SignalDesk</strong>
            <small>Field service coordination</small>
          </span>
        </a>
        <nav aria-label="Primary navigation">
          <button type="button" onClick={() => chooseWorkspace("book")}>
            Book service
          </button>
          <button type="button" onClick={() => chooseWorkspace("operations")}>
            Operations
          </button>
          <a href="/docs/" target="_blank" rel="noreferrer">
            API docs
          </a>
        </nav>
        <div className={`health-badge health-${health}`} aria-live="polite">
          <span aria-hidden="true" />
          {health === "checking" ? "Checking platform" : health === "ready" ? "Platform ready" : "Service issue"}
        </div>
      </header>

      <section className="hero" id="top">
        <div className="hero-copy">
          <p className="eyebrow">Service scheduling that stays accountable</p>
          <h1>Schedule the work. Keep every promise.</h1>
          <p className="hero-lede">
            SignalDesk gives customers a clear booking experience and gives the operations team one
            reliable place to move every appointment from confirmed to complete.
          </p>
          <div className="hero-actions">
            <button className="button button-primary" type="button" onClick={() => chooseWorkspace("book")}>
              Schedule a visit
            </button>
            <button className="button button-secondary" type="button" onClick={() => chooseWorkspace("operations")}>
              Open operations board
            </button>
          </div>
          <ul className="trust-list" aria-label="Service commitments">
            <li>Private PostgreSQL data path</li>
            <li>Live availability</li>
            <li>Request-level traceability</li>
          </ul>
        </div>

        <aside className="platform-card" aria-label="Platform overview">
          <div className="platform-card-header">
            <span>Today&apos;s platform</span>
            <strong>{health === "ready" ? "Operational" : "Checking"}</strong>
          </div>
          <div className="platform-route">
            <div>
              <small>Customer</small>
              <strong>Booking request</strong>
            </div>
            <span aria-hidden="true">→</span>
            <div>
              <small>Cloud Run</small>
              <strong>FastAPI</strong>
            </div>
            <span aria-hidden="true">→</span>
            <div>
              <small>Private data</small>
              <strong>Cloud SQL</strong>
            </div>
          </div>
          <dl className="platform-facts">
            <div>
              <dt>Runtime</dt>
              <dd>Scale 0–3</dd>
            </div>
            <div>
              <dt>Region</dt>
              <dd>us-east1</dd>
            </div>
            <div>
              <dt>Observability</dt>
              <dd>Request IDs</dd>
            </div>
          </dl>
          <p>This interface sends real API requests through the deployed platform.</p>
        </aside>
      </section>

      <section className="workspace-section" id="workspace">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Interactive workspace</p>
            <h2>From customer request to completed service</h2>
          </div>
          <div className="workspace-tabs" role="tablist" aria-label="Choose workspace">
            <button
              type="button"
              role="tab"
              aria-selected={workspace === "book"}
              className={workspace === "book" ? "active" : ""}
              onClick={() => chooseWorkspace("book")}
            >
              Customer booking
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={workspace === "operations"}
              className={workspace === "operations" ? "active" : ""}
              onClick={() => chooseWorkspace("operations")}
            >
              Operations board
            </button>
          </div>
        </div>

        {workspace === "book" ? (
          <div className="booking-layout" role="tabpanel">
            <form className="booking-form card" onSubmit={submitBooking}>
              <div className="card-heading">
                <span className="step-number">01</span>
                <div>
                  <h3>Tell us what you need</h3>
                  <p>Choose a service and a live appointment time. All times are Eastern.</p>
                </div>
              </div>

              {servicesError ? <ErrorNotice message={servicesError} /> : null}

              <div className="field-grid">
                <label>
                  Full name
                  <input
                    name="customerName"
                    autoComplete="name"
                    required
                    maxLength={120}
                    placeholder="Avery Johnson"
                    value={form.customerName}
                    onChange={(event) => setForm({ ...form, customerName: event.target.value })}
                  />
                </label>
                <label>
                  Email address
                  <input
                    name="customerEmail"
                    type="email"
                    autoComplete="email"
                    required
                    placeholder="avery@example.com"
                    value={form.customerEmail}
                    onChange={(event) => setForm({ ...form, customerEmail: event.target.value })}
                  />
                </label>
              </div>

              <label>
                Service
                <select
                  name="service"
                  required
                  value={form.service}
                  onChange={(event) => setForm({ ...form, service: event.target.value })}
                  disabled={!services.length}
                >
                  {!services.length ? <option>Loading services…</option> : null}
                  {services.map((service) => (
                    <option key={service.id} value={service.name}>
                      {service.name} — from ${service.price_from_usd}
                    </option>
                  ))}
                </select>
              </label>

              {selectedService ? (
                <div className="service-summary">
                  <div>
                    <small>Selected service</small>
                    <strong>{selectedService.name}</strong>
                    <span>{selectedService.description}</span>
                  </div>
                  <dl>
                    <div>
                      <dt>Duration</dt>
                      <dd>{selectedService.duration_minutes} min</dd>
                    </div>
                    <div>
                      <dt>Starting at</dt>
                      <dd>${selectedService.price_from_usd}</dd>
                    </div>
                  </dl>
                </div>
              ) : null}

              <label>
                Appointment date
                <input
                  name="date"
                  type="date"
                  required
                  min={minimumBookingDate || undefined}
                  value={form.date}
                  onChange={(event) => {
                    const date = event.target.value;
                    setForm({ ...form, date, scheduledAt: "" });
                    void loadAvailability(date);
                  }}
                />
              </label>

              <fieldset className="time-fieldset">
                <legend>Available arrival windows</legend>
                {slotsLoading ? <p className="muted">Checking live availability…</p> : null}
                {slotsError ? <ErrorNotice message={slotsError} /> : null}
                {!slotsLoading && !slotsError && availableSlots.length === 0 ? (
                  <p className="empty-inline">No times are available on this date. Choose another weekday.</p>
                ) : null}
                <div className="time-grid">
                  {slots.map((slot) => (
                    <button
                      type="button"
                      key={slot.starts_at}
                      disabled={!slot.available}
                      className={form.scheduledAt === slot.starts_at ? "selected" : ""}
                      aria-pressed={form.scheduledAt === slot.starts_at}
                      onClick={() => setForm({ ...form, scheduledAt: slot.starts_at })}
                    >
                      {formatTime(slot.starts_at)}
                      <small>{slot.available ? "Available" : "Booked"}</small>
                    </button>
                  ))}
                </div>
              </fieldset>

              {submitError ? <ErrorNotice {...submitError} /> : null}

              <button className="button button-primary submit-button" type="submit" disabled={submitting}>
                {submitting ? "Confirming securely…" : "Confirm appointment"}
              </button>
              <p className="form-footnote">
                Demo environment: use synthetic information only. No payment is collected.
              </p>
            </form>

            <aside className="journey-panel">
              {confirmation ? (
                <div className="confirmation-card" aria-live="polite" data-testid="confirmation">
                  <span className="confirmation-mark" aria-hidden="true">
                    ✓
                  </span>
                  <p className="eyebrow">Appointment confirmed</p>
                  <h3>{bookingReference(confirmation.booking.id)}</h3>
                  <p>
                    {confirmation.booking.customer_name}, your {confirmation.booking.service.toLowerCase()} is
                    scheduled.
                  </p>
                  <dl>
                    <div>
                      <dt>When</dt>
                      <dd>{formatDateTime(confirmation.booking.scheduled_at)}</dd>
                    </div>
                    <div>
                      <dt>Status</dt>
                      <dd>
                        <StatusPill status={confirmation.booking.status} />
                      </dd>
                    </div>
                    <div>
                      <dt>Request ID</dt>
                      <dd className="request-id">{confirmation.requestId ?? "Not returned"}</dd>
                    </div>
                  </dl>
                  <button className="button button-secondary" type="button" onClick={() => setConfirmation(null)}>
                    Book another service
                  </button>
                </div>
              ) : (
                <div className="journey-card">
                  <p className="eyebrow">What happens next</p>
                  <ol>
                    <li>
                      <span>1</span>
                      <div>
                        <strong>FastAPI validates the request</strong>
                        <p>Name, email, service, timezone, and availability rules are checked.</p>
                      </div>
                    </li>
                    <li>
                      <span>2</span>
                      <div>
                        <strong>Cloud SQL stores the booking</strong>
                        <p>The runtime identity uses a private database path and injected secret.</p>
                      </div>
                    </li>
                    <li>
                      <span>3</span>
                      <div>
                        <strong>The request becomes traceable</strong>
                        <p>A request ID links the browser response to structured Cloud Logging.</p>
                      </div>
                    </li>
                  </ol>
                </div>
              )}
            </aside>
          </div>
        ) : (
          <div className="operations" role="tabpanel">
            <div className="demo-warning">
              <strong>Demonstration operations view</strong>
              <span>
                This public lab must contain synthetic records only. Staff identity and role-based access are the
                next security milestone before real customer use.
              </span>
            </div>

            <div className="stat-grid" aria-label="Booking summary">
              <article>
                <small>Confirmed</small>
                <strong>{bookingCounts.confirmed}</strong>
                <span>Awaiting service</span>
              </article>
              <article>
                <small>Completed</small>
                <strong>{bookingCounts.completed}</strong>
                <span>Work delivered</span>
              </article>
              <article>
                <small>Cancelled</small>
                <strong>{bookingCounts.cancelled}</strong>
                <span>Released capacity</span>
              </article>
            </div>

            <div className="operations-toolbar card">
              <label className="search-field">
                Search bookings
                <input
                  type="search"
                  placeholder="Name, email, service, or reference"
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                  onKeyDown={(event) => {
                    if (event.key === "Enter") void loadBookings();
                  }}
                />
              </label>
              <label>
                Status
                <select
                  value={statusFilter}
                  onChange={(event) => setStatusFilter(event.target.value as BookingStatus | "all")}
                >
                  <option value="all">All statuses</option>
                  <option value="confirmed">Confirmed</option>
                  <option value="completed">Completed</option>
                  <option value="cancelled">Cancelled</option>
                </select>
              </label>
              <button className="button button-primary" type="button" onClick={() => void loadBookings()}>
                Refresh board
              </button>
            </div>

            {operationNotice ? (
              <div className="notice notice-success" role="status">
                {operationNotice}
              </div>
            ) : null}
            {bookingsError ? <ErrorNotice message={bookingsError} /> : null}

            <div className="booking-board" aria-busy={bookingsLoading}>
              {bookingsLoading ? <div className="loading-card">Loading current bookings…</div> : null}
              {!bookingsLoading && bookings.length === 0 ? (
                <div className="empty-state">
                  <span aria-hidden="true">0</span>
                  <h3>No bookings match this view</h3>
                  <p>Adjust the filter or create a synthetic booking from the customer workspace.</p>
                  <button className="button button-secondary" type="button" onClick={() => setWorkspace("book")}>
                    Create a booking
                  </button>
                </div>
              ) : null}
              {bookings.map((booking) => (
                <article className="booking-card" key={booking.id} data-testid="booking-card">
                  <div className="booking-card-main">
                    <div className="booking-reference">
                      <small>Booking</small>
                      <strong>{bookingReference(booking.id)}</strong>
                    </div>
                    <div>
                      <h3>{booking.customer_name}</h3>
                      <a href={`mailto:${booking.customer_email}`}>{booking.customer_email}</a>
                    </div>
                    <div>
                      <small>Service</small>
                      <strong>{booking.service}</strong>
                    </div>
                    <div>
                      <small>Scheduled</small>
                      <strong>{formatDateTime(booking.scheduled_at)}</strong>
                    </div>
                    <StatusPill status={booking.status} />
                  </div>
                  <div className="booking-actions">
                    <span>Created {formatDateTime(booking.created_at)}</span>
                    {booking.status === "confirmed" ? (
                      <div>
                        <button
                          type="button"
                          className="button button-secondary"
                          disabled={updatingId === booking.id}
                          onClick={() => void updateBookingStatus(booking, "cancelled")}
                        >
                          Cancel
                        </button>
                        <button
                          type="button"
                          className="button button-primary"
                          disabled={updatingId === booking.id}
                          onClick={() => void updateBookingStatus(booking, "completed")}
                        >
                          {updatingId === booking.id ? "Updating…" : "Mark complete"}
                        </button>
                      </div>
                    ) : (
                      <span className="terminal-note">This booking is in a terminal state.</span>
                    )}
                  </div>
                </article>
              ))}
            </div>
          </div>
        )}
      </section>

      <footer>
        <div>
          <strong>SignalDesk</strong>
          <span>A SignalOps cloud launch proof asset.</span>
        </div>
        <p>FastAPI · Cloud Run · Private Cloud SQL · Terraform · Keyless delivery</p>
      </footer>
    </main>
  );
}
