import { useCallback, useState } from "react";

export function useToast() {
  const [toast, setToast] = useState(null);

  const showToast = useCallback((message, type = "success") => {
    setToast({ message, type });
    setTimeout(() => setToast(null), 3200);
  }, []);

  const ToastEl = toast ? (
    <div className={`toast toast-${toast.type}`}>{toast.message}</div>
  ) : null;

  return { showToast, ToastEl };
}
