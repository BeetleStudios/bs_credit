let reportData = null;

// Listen for messages from Lua
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'open') {
        reportData = data.report;
        displayCreditReport(reportData);
        document.getElementById('credit-report').style.display = 'flex';
    } else if (data.action === 'close') {
        closeReport();
    }
});

// Close button handler
document.getElementById('close-btn').addEventListener('click', function() {
    closeReport();
});

// ESC key to close
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        closeReport();
    }
});

function closeReport() {
    document.getElementById('credit-report').style.display = 'none';
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}

function displayCreditReport(data) {
    if (!data) return;
    
    // Personal Information
    document.getElementById('firstname').textContent = data.firstname || '-';
    document.getElementById('lastname').textContent = data.lastname || '-';
    document.getElementById('birthdate').textContent = data.birthdate || '-';
    document.getElementById('citizenid').textContent = data.citizenid || '-';
    document.getElementById('jobname').textContent = data.jobName || '-';
    document.getElementById('jobgrade').textContent = data.jobGradeName || '-';
    
    // Financial Information
    const bankBalance = formatCurrency(data.bankBalance || 0);
    document.getElementById('bank-balance').textContent = bankBalance;
    
    const creditScore = data.creditScore || 0;
    document.getElementById('credit-score').textContent = creditScore;
    
    const status = getCreditStatus(creditScore);
    const statusElement = document.getElementById('credit-status');
    statusElement.textContent = status.text;
    statusElement.className = 'status ' + status.class;
    
    // Update credit score meter
    updateCreditScoreMeter(creditScore);
    
    // Credit History
    displayCreditHistory(data.creditHistory || []);
}

function formatCurrency(amount) {
    return '$' + parseFloat(amount).toFixed(2).replace(/\d(?=(\d{3})+\.)/g, '$&,');
}

function getCreditStatus(score) {
    if (score >= 781) {
        return { text: 'Excellent', class: 'excellent' };
    } else if (score >= 661) {
        return { text: 'Good', class: 'good' };
    } else if (score >= 601) {
        return { text: 'Fair', class: 'fair' };
    } else if (score >= 500) {
        return { text: 'Poor', class: 'poor' };
    } else {
        return { text: 'Very Poor', class: 'very-poor' };
    }
}


function updateCreditScoreMeter(score) {
    // Credit score range: 300 to 850
    const minScore = 300;
    const maxScore = 850;
    
    // Ensure score is within valid range
    const clampedScore = Math.max(minScore, Math.min(maxScore, score));
    
    // Determine which range the score falls into
    let activeRange = null;
    let indicatorId = null;
    
    if (clampedScore >= 781) {
        activeRange = '781-850';
        indicatorId = 'score-indicator-5';
    } else if (clampedScore >= 661) {
        activeRange = '661-780';
        indicatorId = 'score-indicator-4';
    } else if (clampedScore >= 601) {
        activeRange = '601-660';
        indicatorId = 'score-indicator-3';
    } else if (clampedScore >= 500) {
        activeRange = '500-600';
        indicatorId = 'score-indicator-2';
    } else {
        activeRange = '300-499';
        indicatorId = 'score-indicator-1';
    }
    
    // Hide all indicators
    for (let i = 1; i <= 5; i++) {
        const indicator = document.getElementById(`score-indicator-${i}`);
        if (indicator) {
            indicator.classList.remove('active');
            indicator.textContent = '';
        }
    }
    
    // Show score in the active range
    const activeIndicator = document.getElementById(indicatorId);
    if (activeIndicator) {
        activeIndicator.classList.add('active');
        activeIndicator.textContent = clampedScore;
    }
}

function displayCreditHistory(history) {
    const historyList = document.getElementById('history-list');
    historyList.innerHTML = '';
    
    if (!history || history.length === 0) {
        historyList.innerHTML = '<div class="no-history">No credit history available</div>';
        return;
    }
    
    history.forEach(entry => {
        const changeAmount = parseFloat(entry.change_amount) || 0;
        const isPositive = changeAmount > 0;
        const changeText = isPositive ? '+' + changeAmount : changeAmount.toString();
        const dateStr = formatDate(entry.created_at);
        
        const historyItem = document.createElement('div');
        historyItem.className = 'history-item ' + (isPositive ? 'positive' : 'negative');
        
        historyItem.innerHTML = `
            <div class="history-left">
                <div class="history-amount ${isPositive ? 'positive' : 'negative'}">
                    ${changeText} Points
                </div>
                <div class="history-description">
                    ${entry.description || 'No description'}
                </div>
            </div>
            <div class="history-date">
                ${dateStr}
            </div>
        `;
        
        historyList.appendChild(historyItem);
    });
}

function formatDate(dateString) {
    if (!dateString || dateString === 'Unknown') {
        return 'Unknown';
    }
    
    try {
        const date = new Date(dateString);
        if (isNaN(date.getTime())) {
            return dateString;
        }
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    } catch (e) {
        return dateString;
    }
}

function GetParentResourceName() {
    // Get resource name from the current URL
    const path = window.location.pathname;
    const match = path.match(/\/([^\/]+)\/html\/index\.html/);
    if (match) {
        return match[1];
    }
    // Fallback: try to get from script src
    try {
        const scripts = document.getElementsByTagName('script');
        for (let i = 0; i < scripts.length; i++) {
            const src = scripts[i].src;
            if (src.includes('script.js')) {
                const urlMatch = src.match(/https?:\/\/cfx-nui-([^\/]+)\//);
                if (urlMatch) {
                    return urlMatch[1];
                }
            }
        }
    } catch (e) {
        console.error('Error getting resource name:', e);
    }
    return 'ns-credit'; // Fallback to default
}
