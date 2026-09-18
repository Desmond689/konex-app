import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AuthProvider } from "./lib/AuthContext";
import RequireStaff from "./components/RequireStaff";
import Layout from "./components/Layout";
import Login from "./pages/Login";
import Dashboard from "./pages/Dashboard";
import Reports from "./pages/Reports";
import Users from "./pages/Users";
import Staff from "./pages/Staff";
import Squads from "./pages/Squads";
import Games from "./pages/Games";
import GameForm from "./pages/GameForm";
<<<<<<< HEAD
import GameMembers from "./pages/GameMembers";
import Audit from "./pages/Audit";
import Appeals from "./pages/Appeals";
import Analytics from "./pages/Analytics";
import Settings from "./pages/Settings";
=======
import Audit from "./pages/Audit";
>>>>>>> origin/main

export default function App() {
  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route
            element={
              <RequireStaff>
                <Layout />
              </RequireStaff>
            }
          >
            <Route path="/" element={<Dashboard />} />
            <Route path="/reports" element={<Reports />} />
            <Route path="/users" element={<Users />} />
            <Route path="/staff" element={<Staff />} />
            <Route path="/squads" element={<Squads />} />
            <Route path="/games" element={<Games />} />
            <Route path="/games/new" element={<GameForm />} />
            <Route path="/games/:id" element={<GameForm />} />
<<<<<<< HEAD
            <Route path="/games/:id/members" element={<GameMembers />} />
            <Route path="/audit" element={<Audit />} />
            <Route path="/appeals" element={<Appeals />} />
            <Route path="/analytics" element={<Analytics />} />
            <Route path="/settings" element={<Settings />} />
=======
            <Route path="/audit" element={<Audit />} />
>>>>>>> origin/main
          </Route>
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}
