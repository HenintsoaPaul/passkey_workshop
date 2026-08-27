# 📋 Application Django de Gestion des Signatures de Documents

Une application web complète pour gérer les signatures numériques de documents avec suivi d'état, vérification et archivage.

## 🎯 Fonctionnalités Principales

### ✅ Gestion des Utilisateurs
- Inscription et authentification sécurisée
- Gestion des profils utilisateur personnalisés
- Rôles (propriétaire de document, signataire)
- Avatar et signature numérique personnalisée
- Informations professionnelles

### ✅ Gestion des Documents
- Téléchargement et création de documents
- Support multi-signataires
- Ordre de signature configurable (parallèle ou séquentiel)
- Dates d'expiration
- Intégrité des fichiers (SHA256)
- Archivage automatique

### ✅ Signature de Documents
- Interface de signature en ligne
- Pad de signature numérique
- Signature par image
- Horodatage automatique
- Traçabilité complète (IP, User-Agent)

### ✅ Suivi et Vérification
- Statut de signature en temps réel
- Barre de progression de signature
- Journaux d'audit complets
- Vérification d'intégrité des fichiers
- Historique détaillé des actions

### ✅ Archivage et Conservation
- Conservation sécurisée des documents
- Stockage des métadonnées de signature
- Recherche et filtrage avancés
- Téléchargement sécurisé
- Exportation des métadonnées

## 📁 Structure du Projet

```
signature_project/
├── signature_project/          # Dossier du projet Django
│   ├── __init__.py
│   ├── settings.py            # Configuration Django
│   ├── urls.py                # URLs principales
│   └── wsgi.py                # Configuration WSGI
│
├── documents/                 # Application Django
│   ├── __init__.py
│   ├── models.py              # Modèles de données
│   ├── views.py               # Logique métier
│   ├── urls.py                # URLs de l'app
│   ├── admin.py               # Interface admin
│   ├── apps.py                # Configuration app
│   └── migrations/            # Migrations BDD
│
├── templates/                 # Templates HTML
│   ├── base.html              # Template de base
│   ├── dashboard.html         # Tableau de bord
│   ├── auth/                  # Templates auth
│   ├── documents/             # Templates documents
│   └── users/                 # Templates utilisateurs
│
├── static/                    # Fichiers statiques
├── media/                     # Fichiers uploadés
├── manage.py                  # Gestion Django
├── requirements.txt           # Dépendances Python
└── README.md                  # Ce fichier
```

## 🗄️ Modèles de Données

### Document
```
- title (CharField): Titre du document
- description (TextField): Description
- file (FileField): Fichier à signer
- owner (ForeignKey): Propriétaire
- status (CharField): État (draft, pending, partially_signed, fully_signed, archived)
- file_hash (CharField): SHA256 du fichier
- file_size (BigIntegerField): Taille du fichier
- due_date (DateTimeField): Date limite
- created_at, updated_at (DateTimeField): Timestamps
```

### DocumentSigner
```
- document (ForeignKey): Document à signer
- user (ForeignKey): Signataire
- signature_status (CharField): État (pending, viewed, signed, rejected, expired)
- order (PositiveIntegerField): Ordre de signature
- signature_data (TextField): Données de signature (Base64)
- digital_signature (CharField): Hash SHA256 de la signature
- signature_date (DateTimeField): Date de signature
- ip_address (GenericIPAddressField): IP du signataire
- user_agent (TextField): Info du navigateur
- rejection_reason (TextField): Raison du rejet
- created_at, updated_at (DateTimeField): Timestamps
```

### SignatureLog
```
- document (ForeignKey): Document concerné
- action (CharField): Type d'action
- user (ForeignKey): Utilisateur
- details (TextField): Détails
- ip_address (GenericIPAddressField): IP
- timestamp (DateTimeField): Quand
```

### UserProfile
```
- user (OneToOneField): Utilisateur
- phone (CharField): Téléphone
- organization (CharField): Organisation
- job_title (CharField): Fonction
- avatar (ImageField): Photo de profil
- signature_image (ImageField): Signature numérique
- bio (TextField): Biographie
- created_at, updated_at (DateTimeField): Timestamps
```

## 🚀 Installation Rapide

### 1. Prérequis
- Python 3.8+
- pip
- virtualenv (recommandé)

### 2. Cloner le projet
```bash
cd signature_project
```

### 3. Créer un environnement virtuel
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
# ou
venv\Scripts\activate  # Windows
```

### 4. Installer les dépendances
```bash
pip install -r requirements.txt
```

### 5. Configurer la base de données
```bash
# Créer les tables
python manage.py makemigrations
python manage.py migrate

# Créer un superutilisateur
python manage.py createsuperuser
```

### 6. Lancer le serveur
```bash
python manage.py runserver
```

L'application est accessible à `http://localhost:8000`

## 👥 Guide d'Utilisation

### Pour les Propriétaires de Documents

#### 1. Créer et télécharger un document
- Aller à "Télécharger" dans la navigation
- Remplir les informations (titre, description, fichier, date limite optionnelle)
- Le document est en statut "Brouillon"

#### 2. Ajouter des signataires
- Ouvrir le document créé
- Cliquer "Ajouter les signataires"
- Sélectionner les utilisateurs
- Définir l'ordre de signature (0 = parallèle, 1,2,3... = séquentiel)
- Le statut passe à "En attente de signature"

#### 3. Suivre l'état des signatures
- Tableau de bord: voir la progression globale
- Détails du document: voir l'état de chaque signataire
- Historique: consulter tous les événements

#### 4. Vérifier les signatures
- Cliquer sur "Vérifier" pour une signature
- Voir les métadonnées (date, IP, User-Agent)
- Valider l'authenticité

#### 5. Archiver les documents
- Une fois signé: cliquer "Archiver"
- Conservation permanente avec métadonnées

### Pour les Signataires

#### 1. Consulter les tâches de signature
- Tableau de bord: voir "Mes tâches de signature"
- Chaque tâche affiche le document et son propriétaire

#### 2. Signer un document
- Cliquer sur "Signer"
- Lire le document (consultable en ligne)
- Signer avec le pad ou uploader une image
- Confirmer la signature
- Vous êtes automatiquement noté comme signataire

#### 3. Rejeter une signature (optionnel)
- Cliquer sur "Rejeter"
- Fournir la raison
- Envoyer

#### 4. Voir l'historique
- Tableau de bord: voir toutes vos signatures
- Profil: statistiques détaillées

## 🔒 Sécurité

- ✅ Authentification Django (PBKDF2)
- ✅ Permissions basées sur les rôles
- ✅ Vérification d'intégrité (SHA256)
- ✅ Horodatage et traçabilité complète
- ✅ Protection CSRF
- ✅ CORS configuré
- ✅ Validation des fichiers

## 📊 API REST

### Endpoints Disponibles

```
GET  /api/documents/              # Lister mes documents
GET  /api/tasks/                  # Lister mes tâches de signature
POST /api/document/<id>/sign/      # Signer un document
```

### Exemple d'utilisation API

```bash
# Récupérer les documents
curl -H "Authorization: Token YOUR_TOKEN" \
  http://localhost:8000/api/documents/

# Signer un document
curl -X POST http://localhost:8000/api/document/1/sign/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Token YOUR_TOKEN" \
  -d '{"signature_data": "base64_encoded_signature"}'
```

## 🛠️ Configuration Avancée

### Variables d'environnement

Créer un fichier `.env`:

```env
DEBUG=False
SECRET_KEY=your-very-secret-key-here
ALLOWED_HOSTS=example.com,www.example.com
DATABASE_URL=postgresql://user:password@localhost/dbname
```

### Utiliser PostgreSQL

Modifier `settings.py`:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'signature_db',
        'USER': 'postgres',
        'PASSWORD': 'password',
        'HOST': 'localhost',
        'PORT': '5432',
    }
}
```

### Configurer le courrier électronique

```python
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST_USER = 'your-email@gmail.com'
EMAIL_HOST_PASSWORD = 'your-password'
DEFAULT_FROM_EMAIL = 'noreply@example.com'
```

## 📦 Déploiement

### Avec Gunicorn

```bash
gunicorn signature_project.wsgi --bind 0.0.0.0:8000 --workers 4
```

### Avec Docker

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN python manage.py collectstatic --noinput

EXPOSE 8000
CMD ["gunicorn", "signature_project.wsgi", "--bind", "0.0.0.0:8000"]
```

### Avec Docker Compose

```yaml
version: '3.8'
services:
  web:
    build: .
    ports:
      - "8000:8000"
    environment:
      - DEBUG=False
      - DATABASE_URL=postgresql://user:password@db/signdb
    depends_on:
      - db
    volumes:
      - ./media:/app/media
      - ./staticfiles:/app/staticfiles

  db:
    image: postgres:15
    environment:
      - POSTGRES_DB=signdb
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

## 🧪 Commandes Utiles

```bash
# Créer les migrations
python manage.py makemigrations

# Appliquer les migrations
python manage.py migrate

# Créer un utilisateur admin
python manage.py createsuperuser

# Accéder au shell Django
python manage.py shell

# Collecter les fichiers statiques
python manage.py collectstatic

# Lancer les tests
python manage.py test

# Afficher les URLs
python manage.py show_urls
```

## 🐛 Dépannage

### Erreur: "No module named 'django'"
```bash
pip install -r requirements.txt
```

### Erreur: "Table does not exist"
```bash
python manage.py migrate
```

### Erreur: "Fichiers statiques non trouvés"
```bash
python manage.py collectstatic --noinput
```

### Erreur de permission lors du téléchargement
- Vérifier les permissions du dossier `media/`
- Linux: `chmod -R 755 media/`

## 📈 Statuts Détaillés

### Statuts de Document
| Statut | Description |
|--------|-------------|
| **Brouillon** | Créé, pas encore envoyé pour signature |
| **En attente** | Signataires ajoutés, en cours de signature |
| **Partiellement signé** | Certains signataires ont signé |
| **Complètement signé** | Tous les signataires ont signé ✓ |
| **Archivé** | Conservé, pas de modification possible |

### Statuts de Signataire
| Statut | Description |
|--------|-------------|
| **En attente** | Signataire n'a pas encore consulté |
| **Consulté** | Document consulté, pas encore signé |
| **Signé** | Document signé ✓ |
| **Refusé** | Signature refusée avec raison |
| **Expiré** | Date limite dépassée ⏰ |

## 📝 Événements Auditables

Chaque action est enregistrée:
- Document créé
- Signataire ajouté/supprimé
- Document consulté
- Document signé
- Signature refusée
- Document téléchargé
- Document archivé

## 🤝 Support et Contribution

Pour les questions:
1. Consulter la documentation
2. Vérifier les logs: `python manage.py shell`
3. Interface admin: `http://localhost:8000/admin/`

## 📄 Licence

MIT License - Libre d'utilisation

## 👨‍💻 Auteur

Application Django créée pour la gestion sécurisée des signatures de documents.

---

**Version**: 1.0.0  
**Dernière mise à jour**: 2024  
**Status**: Production Ready ✅