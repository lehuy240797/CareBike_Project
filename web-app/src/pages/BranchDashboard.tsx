import React from 'react';
import { useAuth } from '../context/AuthContext';
import { dashTitle, eyebrow, pageSubtitle } from '../ui/styles';

const BranchDashboard: React.FC = () => {
    const { user } = useAuth();

    return (
        <div className="mx-auto max-w-[72rem]">
            <div className="mb-10 animate-fade-up">
                <p className={eyebrow}>Overview</p>
                <h1 className={`${dashTitle} mt-2`}>Hello, {user?.username ?? 'there'} 👋</h1>
                <p className={pageSubtitle}>Your branch activity overview</p>
            </div>
        </div>
    );
};

export default BranchDashboard;
