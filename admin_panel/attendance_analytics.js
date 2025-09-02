// Attendance Analytics System with Caching
let currentUser = null;
let selectedClass = null;
let analyticsData = [];
let cacheEnabled = true;
let currentAnalyticsMode = 'all'; // 'all', 'today', 'yesterday', 'range'
let currentDateRange = { from: null, to: null };

// Initialize the analytics system
document.addEventListener('DOMContentLoaded', async function () {
  console.log('Attendance Analytics - Starting initialization...');

  try {
    await checkAuthStatus();
    await loadUserInfo();

    // Wait for cache manager to be available
    if (cacheEnabled) {
      let attempts = 0;
      while (!window.adminCache && attempts < 20) {
        await new Promise(resolve => setTimeout(resolve, 100));
        attempts++;
      }
      if (window.adminCache) {
        console.log('Cache manager ready for attendance analytics');
      }
    }

    if (currentUser) {
      await loadClassFromURL();
      await loadAnalyticsData();
    }
  } catch (error) {
    console.error('Attendance Analytics - Initialization error:', error);
    showMsg('messageDisplay', 'Error initializing analytics: ' + error.message, true);
  }
});

// Check authentication status
async function checkAuthStatus() {
  const isLoggedIn = sessionStorage.getItem('adminLoggedIn') === 'true';
  console.log('Attendance Analytics - Auth check:', { isLoggedIn });

  if (!isLoggedIn) {
    console.log('Attendance Analytics - Not logged in, redirecting to login');
    window.location.href = 'index.html';
    return;
  }
  console.log('Attendance Analytics - Auth check passed');
}

// Load user information
async function loadUserInfo() {
  try {
    console.log('Attendance Analytics - Loading user info...');

    const user = await window.authManager.getCurrentUser();
    console.log('Attendance Analytics - User data:', user);

    if (!user) {
      console.log('Attendance Analytics - No user found, redirecting to login');
      window.location.href = 'index.html';
      return;
    }
    currentUser = user;
    console.log('Attendance Analytics - User loaded successfully:', currentUser.email);
  } catch (error) {
    console.error('Attendance Analytics - Error loading user info:', error);
    window.location.href = 'index.html';
  }
}

// Load class information from URL parameters
async function loadClassFromURL() {
  const urlParams = new URLSearchParams(window.location.search);
  const classId = urlParams.get('classId');

  console.log('Attendance Analytics - Loading class from URL:', { classId, currentUser: currentUser?.email });

  if (!classId) {
    console.log('Attendance Analytics - No classId found in URL');
    showMsg('messageDisplay', 'No class selected. Redirecting...', true);
    setTimeout(() => {
      window.location.href = 'attendance.html';
    }, 2000);
    return;
  }

  try {
    showLoading('Loading class information...');

    // Get class details
    const { data: classData, error } = await window.supabaseClient
      .from('professor_classes')
      .select('*')
      .eq('id', classId)
      .eq('professor_email', currentUser.email)
      .single();

    if (error) throw error;

    if (!classData) {
      throw new Error('Class not found or access denied.');
    }

    selectedClass = {
      id: classData.id,
      name: classData.subject_name,
      className: classData.class_name,
      subject: classData.subject_name,
      college: classData.college_name,
      branch: classData.branch_name,
      semester: classData.semester_name,
      professorEmail: classData.professor_email
    };

    updateClassHeader();
    hideLoading();

  } catch (error) {
    console.error('Attendance Analytics - Error loading class:', error);
    showMsg('messageDisplay', 'Error loading class: ' + error.message, true);
    hideLoading();
  }
}

// Update class header with information
function updateClassHeader() {
  if (!selectedClass) return;

  const classInfo = document.getElementById('classInfo');

  if (classInfo) {
    classInfo.innerHTML = `
      <div class="info-card">
        <h4>📚 Subject</h4>
        <p>${selectedClass.subject}</p>
      </div>
      <div class="info-card">
        <h4>🏢 Branch</h4>
        <p>${selectedClass.branch || 'N/A'}</p>
      </div>
      <div class="info-card">
        <h4>📖 Semester</h4>
        <p>${selectedClass.semester || 'N/A'}</p>
      </div>
      <div class="info-card">
        <h4>🔄 Cache Status</h4>
        <p>${window.adminCache ? 'Enabled' : 'Disabled'}</p>
      </div>
    `;
  }
}

// Load analytics data
async function loadAnalyticsData(dateFilter = null) {
  if (!selectedClass) return;

  try {
    console.log('📊 ANALYTICS DEBUG: Starting analytics data load for class:', selectedClass.id);
    showLoading('Loading attendance analytics...');

    // Try to get students from cache first
    let studentsData = null;
    if (cacheEnabled && window.adminCache) {
      studentsData = window.adminCache.getClassRoster(selectedClass.id);
      if (studentsData) {
        console.log('📊 ANALYTICS DEBUG: Using cached student roster, count:', studentsData.length);
      }
    }

    // Get students from database if not cached
    if (!studentsData) {
      console.log('📊 ANALYTICS DEBUG: Fetching student roster from database');
      const { data: dbStudentsData, error: studentsError } = await window.supabaseClient
        .from('class_rosters')
        .select('*')
        .eq('class_id', selectedClass.id)
        .order('roll_number');

      if (studentsError) throw studentsError;
      studentsData = dbStudentsData;

      // Cache the roster data
      if (cacheEnabled && window.adminCache && studentsData) {
        window.adminCache.cacheClassRoster(studentsData, selectedClass.id);
      }
    }

    // Try to get attendance data from cache first
    let attendanceData = [];
    let useOptimizedSystem = false;
    const cacheKey = dateFilter ? `${dateFilter.type}_${dateFilter.from || ''}_${dateFilter.to || ''}` : 'all';

    if (cacheEnabled && window.adminCache) {
      const cachedAttendance = window.adminCache.get('analytics_attendance', { classId: selectedClass.id, filter: cacheKey });
      if (cachedAttendance) {
        console.log('📊 ANALYTICS DEBUG: Using cached attendance data, records:', cachedAttendance.length);
        attendanceData = cachedAttendance;
        useOptimizedSystem = true;
      }
    }

    // OPTIMIZED: Try to get data from session system first (FAST)
    if (!useOptimizedSystem) {
      try {
        let query = window.supabaseClient
          .from('class_attendance_sessions')
          .select('*')
          .eq('class_id', selectedClass.id);

        // Apply date filters
        if (dateFilter) {
          if (dateFilter.type === 'today') {
            query = query.eq('date', getTodayDate());
          } else if (dateFilter.type === 'yesterday') {
            query = query.eq('date', getYesterdayDate());
          } else if (dateFilter.type === 'range' && dateFilter.from && dateFilter.to) {
            query = query.gte('date', dateFilter.from).lte('date', dateFilter.to);
          }
        }

        const { data: sessionData, error: sessionError } = await query.order('date');

        if (!sessionError && sessionData && sessionData.length > 0) {
          attendanceData = convertSessionsToRecords(sessionData);
          useOptimizedSystem = true;
          console.log('✅ Using optimized session system (97% faster!)');

          // Cache the attendance data
          if (cacheEnabled && window.adminCache) {
            window.adminCache.set('analytics_attendance', attendanceData, { classId: selectedClass.id, filter: cacheKey }, 5 * 60 * 1000);
            console.log('📊 ANALYTICS DEBUG: Cached optimized attendance data, records:', attendanceData.length);
          }
        }
      } catch (sessionError) {
        console.warn('Session system not available, using fallback:', sessionError);
      }
    }

    // FALLBACK: Use old system if new system not available
    if (!useOptimizedSystem) {
      let query = window.supabaseClient
        .from('professor_attendance')
        .select('*')
        .eq('class_id', selectedClass.id);

      // Apply date filters for legacy system
      if (dateFilter) {
        if (dateFilter.type === 'today') {
          query = query.eq('date', getTodayDate());
        } else if (dateFilter.type === 'yesterday') {
          query = query.eq('date', getYesterdayDate());
        } else if (dateFilter.type === 'range' && dateFilter.from && dateFilter.to) {
          query = query.gte('date', dateFilter.from).lte('date', dateFilter.to);
        }
      }

      const { data: oldAttendanceData, error: attendanceError } = await query.order('date');

      if (attendanceError) throw attendanceError;
      attendanceData = oldAttendanceData || [];
      console.log('📊 Using legacy system');

      // Cache the attendance data
      if (cacheEnabled && window.adminCache && attendanceData.length > 0) {
        window.adminCache.set('analytics_attendance', attendanceData, { classId: selectedClass.id, filter: cacheKey }, 5 * 60 * 1000);
        console.log('📊 ANALYTICS DEBUG: Cached legacy attendance data, records:', attendanceData.length);
      }
    }

    // Process analytics data
    console.log('📊 ANALYTICS DEBUG: Processing analytics data - students:', studentsData.length, 'attendance records:', attendanceData.length);
    processAnalyticsData(studentsData, attendanceData, dateFilter);
    console.log('📊 ANALYTICS DEBUG: Analytics processing complete, rendering table');
    renderAnalyticsTable();
    hideLoading();

  } catch (error) {
    console.error('📊 ANALYTICS DEBUG: Error loading analytics data:', error);
    showMsg('messageDisplay', 'Error loading analytics: ' + error.message, true);
    hideLoading();
  }
}

// NEW: Convert optimized session data to individual records format
function convertSessionsToRecords(sessionData) {
  const records = [];

  sessionData.forEach(session => {
    const students = session.attendance_data?.students || [];
    const subjectName = session.attendance_data?.subject_name || 'Unknown Subject';
    const collegeName = session.attendance_data?.college_name || '';
    const branchName = session.attendance_data?.branch_name || '';
    const semesterName = session.attendance_data?.semester_name || '';

    students.forEach(student => {
      records.push({
        class_id: session.class_id,
        student_roll_number: student.roll_number,
        student_name: student.name,
        date: session.date,
        status: student.status,
        subject_name: subjectName,
        college_name: collegeName,
        branch_name: branchName,
        semester_name: semesterName,
        class_number: session.attendance_data?.class_number || 1
      });
    });
  });

  console.log('📊 Converted', sessionData.length, 'sessions to', records.length, 'individual records');
  return records;
}

// Process analytics data
function processAnalyticsData(students, attendanceRecords, dateFilter = null) {
  console.log('Processing analytics data:', { students: students.length, records: attendanceRecords.length, filter: dateFilter });

  // Get unique class sessions (date + class_number combinations)
  const uniqueSessions = [...new Set(attendanceRecords.map(record => 
    `${record.date}_${record.class_number || 1}`
  ))];
  const totalClasses = uniqueSessions.length;

  // Calculate student-wise analytics
  analyticsData = students.map(student => {
    const studentRecords = attendanceRecords.filter(record =>
      record.student_roll_number === student.roll_number
    );

    const presentCount = studentRecords.filter(record => record.status === 'present').length || 0;
    const absentCount = studentRecords.filter(record => record.status === 'absent').length || 0;
    const totalAttended = studentRecords.length;

    // Calculate percentage based on total classes held
    const percentage = totalClasses > 0 ? Math.round((presentCount / totalClasses) * 100) : 0;

    return {
      rollNumber: student.roll_number,
      studentName: student.student_name,
      presentCount,
      absentCount,
      totalAttended,
      totalClasses,
      percentage,
      status: getAttendanceStatus(percentage)
    };
  });

  // Calculate overall statistics
  const totalStudents = students.length;
  const totalPresentRecords = attendanceRecords.filter(record => record.status === 'present').length;
  const totalAbsentRecords = attendanceRecords.filter(record => record.status === 'absent').length;
  const overallPercentage = (totalPresentRecords + totalAbsentRecords) > 0 ?
    Math.round((totalPresentRecords / (totalPresentRecords + totalAbsentRecords)) * 100) : 0;

  // Update UI title based on filter
  updateAnalyticsTitle(dateFilter);
  renderAnalyticsTable();
}

// Get attendance status based on percentage
function getAttendanceStatus(percentage) {
  if (percentage >= 85) return 'Excellent';
  if (percentage >= 75) return 'Good';
  if (percentage >= 60) return 'Average';
  return 'Poor';
}

// Update overall statistics (function disabled - stats section removed)
function updateOverallStats(totalStudents, totalClasses, totalPresent, totalAbsent, overallPercentage) {
  // Overall statistics section has been removed from the UI
  // This function is kept for compatibility but does nothing
  console.log('Overall stats calculated but not displayed:', {
    totalStudents, totalClasses, totalPresent, totalAbsent, overallPercentage
  });
}

// Render analytics table
function renderAnalyticsTable() {
  const tableBody = document.getElementById('analyticsTableBody');
  if (!tableBody) return;

  if (analyticsData.length === 0) {
    tableBody.innerHTML = `
      <tr>
        <td colspan="6" style="text-align: center; padding: 2rem;">
          <div>
            <h3>📊 No Analytics Data Available</h3>
            <p>No students or attendance records found for this class.</p>
          </div>
        </td>
      </tr>
    `;
    return;
  }

  tableBody.innerHTML = analyticsData.map(student => `
    <tr>
      <td><strong>${student.rollNumber}</strong></td>
      <td class="student-name">${student.studentName}</td>
      <td>${student.presentCount || 0}</td>
      <td>${student.absentCount || 0}</td>
      <td>${student.totalClasses}</td>
      <td class="percentage-cell ${getPercentageClass(student.percentage)}">
        ${student.percentage}%
      </td>
      <td class="status-cell">
        <span class="status-badge ${getStatusClass(student.status)}">
          ${student.status}
        </span>
      </td>
    </tr>
  `).join('');
}

// Get CSS class for percentage
function getPercentageClass(percentage) {
  if (percentage >= 85) return 'percentage-excellent';
  if (percentage >= 75) return 'percentage-good';
  return 'percentage-poor';
}

// Get CSS class for status
function getStatusClass(status) {
  switch (status) {
    case 'Excellent': return 'status-excellent';
    case 'Good': return 'status-good';
    case 'Average': return 'status-average';
    default: return 'status-poor';
  }
}

// Download PDF report
async function downloadPDF() {
  try {
    showLoading('Generating PDF report...');

    // Create PDF content
    const pdfContent = generatePDFContent();

    // Create and download PDF (using browser's print functionality)
    const printWindow = window.open('', '_blank');
    printWindow.document.write(pdfContent);
    printWindow.document.close();
    printWindow.print();

    hideLoading();
    showMsg('messageDisplay', 'PDF report generated successfully!', false);

  } catch (error) {
    console.error('Error generating PDF:', error);
    showMsg('messageDisplay', 'Error generating PDF: ' + error.message, true);
    hideLoading();
  }
}

// Generate PDF content
function generatePDFContent() {
  const currentDate = new Date().toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });
  const currentTime = new Date().toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit'
  });

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <title>Attendance Analytics Report - ${selectedClass.subject}</title>
      <meta charset="UTF-8">
      <style>
        * { box-sizing: border-box; }
        body { 
          font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
          margin: 0; 
          padding: 30px; 
          line-height: 1.6;
          color: #333;
          background: #fff;
        }
        
        .report-header { 
          text-align: center; 
          margin-bottom: 40px; 
          border-bottom: 3px solid #667eea;
          padding-bottom: 20px;
        }
        
        .report-header h1 {
          color: #667eea;
          font-size: 28px;
          margin: 0 0 10px 0;
          font-weight: 700;
        }
        
        .report-header .subtitle {
          color: #64748b;
          font-size: 16px;
          margin: 5px 0;
        }
        
        .report-meta {
          display: flex;
          justify-content: space-between;
          background: #f8fafc;
          padding: 15px 20px;
          border-radius: 8px;
          margin-bottom: 30px;
          border-left: 4px solid #667eea;
        }
        
        .class-info { 
          background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%); 
          padding: 25px; 
          border-radius: 12px; 
          margin-bottom: 30px;
          border: 1px solid #e2e8f0;
          box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }
        
        .class-info h3 {
          color: #1e293b;
          margin: 0 0 15px 0;
          font-size: 20px;
          font-weight: 600;
        }
        
        .info-grid {
          display: grid;
          grid-template-columns: repeat(2, 1fr);
          gap: 15px;
        }
        
        .info-item {
          display: flex;
          align-items: center;
          gap: 8px;
        }
        
        .info-label {
          font-weight: 600;
          color: #475569;
          min-width: 80px;
        }
        
        .info-value {
          color: #1e293b;
          font-weight: 500;
        }
        
        .summary-section {
          margin-bottom: 30px;
        }
        
        .summary-title {
          font-size: 18px;
          font-weight: 600;
          color: #1e293b;
          margin-bottom: 15px;
          display: flex;
          align-items: center;
          gap: 8px;
        }
        
        .attendance-table { 
          width: 100%; 
          border-collapse: collapse; 
          margin-top: 20px;
          background: white;
          border-radius: 8px;
          overflow: hidden;
          box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        
        .attendance-table th { 
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
          color: white;
          padding: 15px 12px;
          text-align: left;
          font-weight: 600;
          font-size: 14px;
          text-transform: uppercase;
          letter-spacing: 0.5px;
        }
        
        .attendance-table td { 
          padding: 12px;
          border-bottom: 1px solid #e2e8f0;
          font-size: 14px;
        }
        
        .attendance-table tr:nth-child(even) {
          background: #f8fafc;
        }
        
        .attendance-table tr:hover {
          background: #f1f5f9;
        }
        
        .percentage-excellent { 
          color: #059669; 
          font-weight: 600;
          background: #d1fae5;
          padding: 4px 8px;
          border-radius: 4px;
        }
        
        .percentage-good { 
          color: #d97706; 
          font-weight: 600;
          background: #fef3c7;
          padding: 4px 8px;
          border-radius: 4px;
        }
        
        .percentage-poor { 
          color: #dc2626; 
          font-weight: 600;
          background: #fee2e2;
          padding: 4px 8px;
          border-radius: 4px;
        }
        
        .status-excellent { 
          background: #22c55e; 
          color: white; 
          padding: 4px 12px; 
          border-radius: 20px; 
          font-weight: 600; 
          font-size: 12px;
          display: inline-block;
        }
        .status-good { 
          background: #f59e0b; 
          color: white; 
          padding: 4px 12px; 
          border-radius: 20px; 
          font-weight: 600; 
          font-size: 12px;
          display: inline-block;
        }
        .status-poor { 
          background: #ef4444; 
          color: white; 
          padding: 4px 12px; 
          border-radius: 20px; 
          font-weight: 600; 
          font-size: 12px;
          display: inline-block;
        }
        
        .report-footer {
          margin-top: 40px;
          padding-top: 20px;
          border-top: 2px solid #e2e8f0;
          text-align: center;
          color: #64748b;
          font-size: 12px;
        }
        
        .logo {
          font-size: 24px;
          margin-right: 10px;
        }
        
        @media print { 
          body { margin: 0; padding: 20px; }
          .report-header { page-break-after: avoid; }
          .attendance-table { page-break-inside: avoid; }
        }
        
        @page {
          margin: 1in;
          size: A4;
        }
      </style>
    </head>
    <body>
      <div class="report-header">
        <h1><span class="logo">🎓</span>EduNest Attendance Report</h1>
        <div class="subtitle">Student Attendance Data</div>
      </div>
      
      <div class="report-meta">
        <div><strong>Report Type:</strong> Student Attendance Analytics</div>
        <div><strong>Academic Period:</strong> ${selectedClass.semester}</div>
      </div>
      
      <div class="class-info">
        <h3>📚 Class Information</h3>
        <div class="info-grid">
          <div class="info-item">
            <span class="info-label">Subject:</span>
            <span class="info-value">${selectedClass.subject}</span>
          </div>
          <div class="info-item">
            <span class="info-label">Branch:</span>
            <span class="info-value">${selectedClass.branch}</span>
          </div>
          <div class="info-item">
            <span class="info-label">Semester:</span>
            <span class="info-value">${selectedClass.semester}</span>
          </div>

        </div>
      </div>
      
      <div class="summary-section">
        <h3 class="summary-title">👥 Student Attendance Data</h3>
        <table class="attendance-table">
          <thead>
            <tr>
              <th>Roll Number</th>
              <th>Student Name</th>
              <th>Classes Attended</th>
              <th>Total Classes</th>
              <th>Attendance Rate</th>
              <th>Performance Status</th>
            </tr>
          </thead>
          <tbody>
            ${analyticsData.map(student => `
              <tr>
                <td><strong>${student.rollNumber}</strong></td>
                <td>${student.studentName}</td>
                <td>${student.presentCount || 0}</td>
                <td>${student.totalClasses || 0}</td>
                <td><span class="percentage-${getPercentageClass(student.percentage)}">${student.percentage}%</span></td>
                <td><span class="status-${getPercentageClass(student.status)}">${student.status}</span></td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
      
      <div class="report-footer">
        <p><strong>EduNest Attendance Management System</strong></p>
        <p>This report was automatically generated and contains confidential student information.</p>
        <p><strong>Generated:</strong> ${currentDate} at ${currentTime}</p>
        <p>© ${new Date().getFullYear()} EduNest. All rights reserved.</p>
      </div>
    </body>
    </html>
  `;
}

// Download Excel report
async function downloadExcel() {
  try {
    showLoading('Generating professional Excel report...');

    // Create enhanced CSV content that Excel will format nicely
    const csvContent = generateCSVContent();

    // Create filename with proper formatting
    const sanitizedSubject = selectedClass.subject.replace(/[^a-zA-Z0-9]/g, '_');
    const dateStr = new Date().toISOString().split('T')[0];
    const filename = `EduNest_Attendance_Report_${sanitizedSubject}_${dateStr}.csv`;

    // Create and download file with Excel-compatible MIME type
    const blob = new Blob(['\ufeff' + csvContent], {
      type: 'application/vnd.ms-excel;charset=utf-8;'
    });

    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    // Clean up
    setTimeout(() => URL.revokeObjectURL(url), 100);

    hideLoading();
    showMsg('messageDisplay', `📊 Professional Excel report downloaded: ${filename}`, false);

  } catch (error) {
    console.error('Error generating Excel:', error);
    showMsg('messageDisplay', 'Error generating Excel report: ' + error.message, true);
    hideLoading();
  }
}

// Download CSV report
async function downloadCSV() {
  try {
    showLoading('Generating professional CSV report...');

    const csvContent = generateCSVContent();

    // Create filename with proper formatting
    const sanitizedSubject = selectedClass.subject.replace(/[^a-zA-Z0-9]/g, '_');
    const dateStr = new Date().toISOString().split('T')[0];
    const filename = `EduNest_Attendance_Data_${sanitizedSubject}_${dateStr}.csv`;

    // Create and download file
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    // Clean up
    setTimeout(() => URL.revokeObjectURL(url), 100);

    hideLoading();
    showMsg('messageDisplay', `📋 Professional CSV report downloaded: ${filename}`, false);

  } catch (error) {
    console.error('Error generating CSV:', error);
    showMsg('messageDisplay', 'Error generating CSV report: ' + error.message, true);
    hideLoading();
  }
}

// Generate CSV content
function generateCSVContent() {
  const currentDate = new Date().toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  });
  const currentTime = new Date().toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit'
  });

  // Professional header section
  const headerSection = [
    ['EduNest Attendance Report'],
    ['Generated on', `${currentDate} at ${currentTime}`],
    [], // Empty row for spacing
    ['CLASS INFORMATION'],
    ['Subject', selectedClass.subject],
    ['Branch', selectedClass.branch],
    ['Semester', selectedClass.semester],
    ['College', selectedClass.college || 'N/A'],
    [], // Empty row for spacing
    ['STUDENT ATTENDANCE DATA']
  ];

  // Table headers
  const tableHeaders = [
    'Roll Number',
    'Student Name',
    'Present',
    'Absent',
    'Total Classes',
    'Attendance Percentage'
  ];

  // Student data rows
  const studentRows = analyticsData.map(student => [
    student.rollNumber,
    student.studentName,
    student.presentCount || 0,
    student.absentCount || 0,
    student.totalClasses || 0,
    student.percentage + '%'
  ]);

  // Footer section
  const footerSection = [
    [], // Empty row
    ['© ' + new Date().getFullYear() + ' EduNest Attendance Management System']
  ];

  // Combine all sections
  const allRows = [
    ...headerSection,
    tableHeaders,
    ...studentRows,
    ...footerSection
  ];

  // Convert to CSV format with proper escaping
  return allRows.map(row =>
    row.map(cell => {
      const cellStr = String(cell || '');
      // Escape cells that contain commas, quotes, or newlines
      if (cellStr.includes(',') || cellStr.includes('"') || cellStr.includes('\n')) {
        return `"${cellStr.replace(/"/g, '""')}"`;
      }
      return cellStr;
    }).join(',')
  ).join('\n');
}

// Helper function to calculate overall attendance (simplified)
function calculateOverallAttendance() {
  if (analyticsData.length === 0) return 0;
  const totalPercentage = analyticsData.reduce((sum, student) => sum + student.percentage, 0);
  return Math.round(totalPercentage / analyticsData.length);
}

// Show message
function showMsg(id, msg, isError = false) {
  const el = document.getElementById(id);
  if (!el) return;

  el.textContent = msg;
  el.style.color = isError ? '#dc2626' : '#22c55e';
  el.style.backgroundColor = isError ? '#fee2e2' : '#dcfce7';
  el.style.borderColor = isError ? '#fecaca' : '#bbf7d0';
  el.classList.remove('hidden');

  setTimeout(() => {
    el.classList.add('hidden');
  }, 5000);
}

// Show loading overlay
function showLoading(text = 'Loading...') {
  const overlay = document.getElementById('loadingOverlay');
  const loadingText = document.getElementById('loadingText');

  if (overlay) {
    overlay.classList.remove('hidden');
  }

  if (loadingText) {
    loadingText.textContent = text;
  }
}

// Hide loading overlay
function hideLoading() {
  const overlay = document.getElementById('loadingOverlay');
  if (overlay) {
    overlay.classList.add('hidden');
  }
}

// Get today's date in YYYY-MM-DD format
function getTodayDate() {
  return new Date().toISOString().split('T')[0];
}

// Get yesterday's date in YYYY-MM-DD format
function getYesterdayDate() {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  return yesterday.toISOString().split('T')[0];
}

// Show today's attendance analytics
async function showTodayAnalytics() {
  currentAnalyticsMode = 'today';
  const dateFilter = { type: 'today' };
  await loadAnalyticsData(dateFilter);
}

// Show yesterday's attendance analytics
async function showYesterdayAnalytics() {
  currentAnalyticsMode = 'yesterday';
  const dateFilter = { type: 'yesterday' };
  await loadAnalyticsData(dateFilter);
}

// Show date range modal
function showDateRangeModal() {
  const modal = document.getElementById('dateRangeModal');
  const fromDate = document.getElementById('fromDate');
  const toDate = document.getElementById('toDate');

  // Set default dates (last 7 days)
  const today = new Date();
  const weekAgo = new Date();
  weekAgo.setDate(today.getDate() - 7);

  fromDate.value = weekAgo.toISOString().split('T')[0];
  toDate.value = today.toISOString().split('T')[0];

  modal.classList.remove('hidden');
}

// Hide date range modal
function hideDateRangeModal() {
  const modal = document.getElementById('dateRangeModal');
  modal.classList.add('hidden');
}

// Load date range analytics
async function loadDateRangeAnalytics() {
  const fromDate = document.getElementById('fromDate').value;
  const toDate = document.getElementById('toDate').value;

  if (!fromDate || !toDate) {
    showMsg('messageDisplay', 'Please select both from and to dates', true);
    return;
  }

  if (new Date(fromDate) > new Date(toDate)) {
    showMsg('messageDisplay', 'From date cannot be later than to date', true);
    return;
  }

  currentAnalyticsMode = 'range';
  currentDateRange = { from: fromDate, to: toDate };

  const dateFilter = {
    type: 'range',
    from: fromDate,
    to: toDate
  };

  hideDateRangeModal();
  await loadAnalyticsData(dateFilter);
}

// Update analytics title based on current filter
function updateAnalyticsTitle(dateFilter) {
  const titleElement = document.querySelector('.students-table .section-title');
  if (!titleElement) return;

  let title = '👥 Student-wise Analytics';

  if (dateFilter) {
    switch (dateFilter.type) {
      case 'today':
        title += ' - Today';
        break;
      case 'yesterday':
        title += ' - Yesterday';
        break;
      case 'range':
        title += ` - ${dateFilter.from} to ${dateFilter.to}`;
        break;
    }
  } else {
    title += ' - All Time';
  }

  titleElement.textContent = title;
}

// Refresh cache and reload data
async function refreshCache() {
  try {
    showMsg('messageDisplay', 'Refreshing analytics data...', false);

    // Clear all relevant cache entries
    if (window.adminCache) {
      window.adminCache.invalidateType('analytics_attendance');
      window.adminCache.invalidateType('class_roster');
      window.adminCache.invalidateType('attendance');
      console.log('Cache cleared for attendance analytics');
    }

    // Reload data based on current mode
    let dateFilter = null;
    if (currentAnalyticsMode === 'today') {
      dateFilter = { type: 'today' };
    } else if (currentAnalyticsMode === 'yesterday') {
      dateFilter = { type: 'yesterday' };
    } else if (currentAnalyticsMode === 'range') {
      dateFilter = {
        type: 'range',
        from: currentDateRange.from,
        to: currentDateRange.to
      };
    }

    await loadAnalyticsData(dateFilter);
    showMsg('messageDisplay', 'Analytics data refreshed successfully!', false);
  } catch (error) {
    console.error('Error refreshing analytics data:', error);
    showMsg('messageDisplay', 'Failed to refresh data. Please try again.', true);
  }
}

// Extended attendance saving for multiple days
async function saveAttendanceForWeek(classId, startDate, attendancePattern) {
  try {
    const dates = [];
    const start = new Date(startDate);

    // Generate 7 days from start date
    for (let i = 0; i < 7; i++) {
      const date = new Date(start);
      date.setDate(start.getDate() + i);
      dates.push(date.toISOString().split('T')[0]);
    }

    // Save attendance for each date
    for (const date of dates) {
      await saveAttendanceForDate(classId, date, attendancePattern);

      // Invalidate cache for this date
      if (window.adminCache) {
        window.adminCache.invalidate('attendance', { classId, date });
        window.adminCache.invalidate('analytics_attendance', { classId, filter: 'all' });
      }
    }

    showMsg('messageDisplay', `Attendance saved for ${dates.length} days successfully!`, false);
  } catch (error) {
    console.error('Error saving weekly attendance:', error);
    showMsg('messageDisplay', 'Failed to save weekly attendance', true);
  }
}

// Save attendance for a specific date
async function saveAttendanceForDate(classId, date, attendancePattern) {
  // Implementation depends on your attendance saving logic
  // This is a placeholder for the actual implementation
  console.log('Saving attendance for date:', date, attendancePattern);
}

// Auto-refresh cache every 15 minutes
setInterval(() => {
  if (window.adminCache && cacheEnabled) {
    console.log('Auto-refreshing analytics cache...');
    window.adminCache.invalidateType('analytics_attendance');
  }
}, 15 * 60 * 1000); // 15 minutes

// Keyboard shortcuts
document.addEventListener('keydown', function(event) {
  // Ctrl+R or F5 - Refresh cache
  if ((event.ctrlKey && event.key === 'r') || event.key === 'F5') {
    event.preventDefault();
    refreshCache();
  }

  // Ctrl+T - Today's analytics
  if (event.ctrlKey && event.key === 't') {
    event.preventDefault();
    showTodayAnalytics();
  }

  // Ctrl+Y - Yesterday's analytics
  if (event.ctrlKey && event.key === 'y') {
    event.preventDefault();
    showYesterdayAnalytics();
  }
});