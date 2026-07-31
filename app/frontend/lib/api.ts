export type BookingStatus = "confirmed" | "completed" | "cancelled";

export interface ServiceOption {
  id: string;
  name: string;
  duration_minutes: number;
  price_from_usd: number;
  description: string;
}

export interface AvailabilitySlot {
  starts_at: string;
  available: boolean;
}

export interface AvailabilityResponse {
  date: string;
  timezone: string;
  slots: AvailabilitySlot[];
}

export interface Booking {
  id: string;
  customer_name: string;
  customer_email: string;
  service: string;
  scheduled_at: string;
  status: BookingStatus;
  created_at: string;
}

export interface BookingInput {
  customer_name: string;
  customer_email: string;
  service: string;
  scheduled_at: string;
}

export interface ApiResult<T> {
  data: T;
  requestId: string | null;
}

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly requestId: string | null,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

function errorMessage(payload: unknown): string {
  if (!payload || typeof payload !== "object" || !("detail" in payload)) {
    return "The request could not be completed. Please try again.";
  }

  const detail = payload.detail;
  if (typeof detail === "string") return detail;
  if (Array.isArray(detail)) {
    return detail
      .map((item) =>
        item && typeof item === "object" && "msg" in item ? String(item.msg) : "Invalid value",
      )
      .join(". ");
  }
  return "The request could not be completed. Please try again.";
}

async function request<T>(path: string, init?: RequestInit): Promise<ApiResult<T>> {
  const requestId = crypto.randomUUID();
  const response = await fetch(path, {
    ...init,
    cache: "no-store",
    headers: {
      Accept: "application/json",
      "x-request-id": requestId,
      ...(init?.body ? { "content-type": "application/json" } : {}),
      ...init?.headers,
    },
  });

  const responseRequestId = response.headers.get("x-request-id") ?? requestId;
  const payload: unknown = await response.json().catch(() => null);
  if (!response.ok) {
    throw new ApiError(errorMessage(payload), response.status, responseRequestId);
  }
  return { data: payload as T, requestId: responseRequestId };
}

export const api = {
  health: () => request<{ status: string }>("/health/ready"),
  services: () => request<ServiceOption[]>("/api/v1/services"),
  availability: (date: string) =>
    request<AvailabilityResponse>(`/api/v1/availability?date=${encodeURIComponent(date)}`),
  createBooking: (input: BookingInput) =>
    request<Booking>("/api/v1/bookings", {
      method: "POST",
      body: JSON.stringify(input),
    }),
  listBookings: (status?: BookingStatus | "all", search?: string) => {
    const params = new URLSearchParams();
    if (status && status !== "all") params.set("status", status);
    if (search?.trim()) params.set("search", search.trim());
    const query = params.toString();
    return request<Booking[]>(`/api/v1/bookings${query ? `?${query}` : ""}`);
  },
  updateStatus: (id: string, status: BookingStatus) =>
    request<Booking>(`/api/v1/bookings/${encodeURIComponent(id)}/status`, {
      method: "PATCH",
      body: JSON.stringify({ status }),
    }),
};
