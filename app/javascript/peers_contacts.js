// Phone Contacts API for finding peers
document.addEventListener('DOMContentLoaded', function() {
  const findFromContactsBtn = document.getElementById('find-from-contacts-btn');
  const contactsStatus = document.getElementById('contacts-status');

  if (findFromContactsBtn) {
    findFromContactsBtn.addEventListener('click', function() {
      findFromContacts();
    });
  }

  function findFromContacts() {
    // Check if Contacts API is available
    if (!('contacts' in navigator && 'ContactsManager' in window)) {
      contactsStatus.style.display = 'block';
      contactsStatus.innerHTML = '<p style="color: #d32f2f;">Contacts API is not supported in this browser. Please use Chrome on Android or a supported browser.</p>';
      return;
    }

    const contactsManager = new ContactsManager();
    
    // Request permission and get contacts
    contactsManager.select(['name', 'email', 'tel'])
      .then(function(contacts) {
        if (contacts.length === 0) {
          contactsStatus.style.display = 'block';
          contactsStatus.innerHTML = '<p style="color: #666;">No contacts selected or available.</p>';
          return;
        }

        // Show loading status
        contactsStatus.style.display = 'block';
        contactsStatus.innerHTML = '<p style="color: #666;">Processing ' + contacts.length + ' contacts...</p>';

        // Format contacts data
        const contactsData = contacts.map(function(contact) {
          const name = contact.name ? (contact.name[0] || contact.name) : '';
          const email = contact.email ? (contact.email[0] || contact.email) : '';
          const phone = contact.tel ? (contact.tel[0] || contact.tel) : '';

          return {
            name: name,
            email: email,
            phone: phone
          };
        });

        // Send to server
        sendContactsToServer(contactsData);
      })
      .catch(function(error) {
        console.error('Error accessing contacts:', error);
        contactsStatus.style.display = 'block';
        contactsStatus.innerHTML = '<p style="color: #d32f2f;">Error accessing contacts: ' + error.message + '</p>';
      });
  }

  function sendContactsToServer(contactsData) {
    const form = document.createElement('form');
    form.method = 'POST';
    form.action = '/peers/find_peers';
    
    // Add CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]');
    if (csrfToken) {
      const csrfInput = document.createElement('input');
      csrfInput.type = 'hidden';
      csrfInput.name = 'authenticity_token';
      csrfInput.value = csrfToken.getAttribute('content');
      form.appendChild(csrfInput);
    }

    // Add contacts data
    const contactsInput = document.createElement('input');
    contactsInput.type = 'hidden';
    contactsInput.name = 'contacts';
    contactsInput.value = JSON.stringify(contactsData);
    form.appendChild(contactsInput);

    document.body.appendChild(form);
    form.submit();
  }

  // Fallback for browsers that don't support Contacts API
  // This provides a manual input option
  if (!('contacts' in navigator && 'ContactsManager' in window)) {
    const fallbackHtml = `
      <div style="margin-top: 10px;">
        <p style="color: #666; margin-bottom: 10px;">Contacts API not available. You can manually upload contacts:</p>
        <input type="file" id="contacts-file" accept=".vcf,.csv" style="margin-bottom: 10px;">
        <button id="upload-contacts-btn" class="add-peer-btn" style="background: #28a745; color: white; border: none; padding: 8px 16px; border-radius: 5px; cursor: pointer;">
          Upload Contacts
        </button>
      </div>
    `;
    
    if (findFromContactsBtn && findFromContactsBtn.parentElement) {
      findFromContactsBtn.parentElement.insertAdjacentHTML('beforeend', fallbackHtml);
      
      const uploadBtn = document.getElementById('upload-contacts-btn');
      const contactsFile = document.getElementById('contacts-file');
      
      if (uploadBtn && contactsFile) {
        uploadBtn.addEventListener('click', function() {
          if (contactsFile.files.length > 0) {
            parseContactsFile(contactsFile.files[0]);
          } else {
            alert('Please select a contacts file (.vcf or .csv)');
          }
        });
      }
    }
  }

  function parseContactsFile(file) {
    const reader = new FileReader();
    
    reader.onload = function(e) {
      const content = e.target.result;
      const contactsData = [];

      if (file.name.endsWith('.vcf')) {
        // Parse VCF (vCard) format
        const vcards = content.split('BEGIN:VCARD');
        vcards.forEach(function(vcard) {
          if (!vcard.trim()) return;
          
          const lines = vcard.split('\n');
          let name = '';
          let email = '';
          let phone = '';

          lines.forEach(function(line) {
            if (line.startsWith('FN:')) {
              name = line.substring(3).trim();
            } else if (line.startsWith('EMAIL')) {
              email = line.split(':')[1]?.trim() || '';
            } else if (line.startsWith('TEL')) {
              phone = line.split(':')[1]?.trim() || '';
            }
          });

          if (name || email || phone) {
            contactsData.push({ name: name, email: email, phone: phone });
          }
        });
      } else if (file.name.endsWith('.csv')) {
        // Parse CSV format (simple implementation)
        const lines = content.split('\n');
        const headers = lines[0].split(',').map(h => h.trim().toLowerCase());
        
        for (let i = 1; i < lines.length; i++) {
          if (!lines[i].trim()) continue;
          
          const values = lines[i].split(',');
          const contact = {};
          
          headers.forEach(function(header, index) {
            if (header.includes('name')) {
              contact.name = values[index]?.trim() || '';
            } else if (header.includes('email')) {
              contact.email = values[index]?.trim() || '';
            } else if (header.includes('phone') || header.includes('tel')) {
              contact.phone = values[index]?.trim() || '';
            }
          });

          if (contact.name || contact.email || contact.phone) {
            contactsData.push(contact);
          }
        }
      }

      if (contactsData.length > 0) {
        contactsStatus.style.display = 'block';
        contactsStatus.innerHTML = '<p style="color: #666;">Processing ' + contactsData.length + ' contacts...</p>';
        sendContactsToServer(contactsData);
      } else {
        contactsStatus.style.display = 'block';
        contactsStatus.innerHTML = '<p style="color: #d32f2f;">No valid contacts found in file.</p>';
      }
    };

    reader.readAsText(file);
  }
});

