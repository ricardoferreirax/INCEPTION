const questions =
[
    {
        question: "What is the main role of NGINX in the Inception project?",
        answers:
        [
            "Store the WordPress database",
            "Handle HTTPS requests and forward PHP requests",
            "Execute PHP code",
            "Store Docker volumes"
        ],
        correct: 1,
        explanation: "NGINX is the entry point of the Inception website. It receives HTTPS connections on port 443 and handles TLS encryption. When PHP is requested, NGINX forwards the request to PHP-FPM running inside the WordPress container."
    },
    {
        question: "Why does WordPress use PHP-FPM instead of running PHP inside NGINX?",
        answers:
        [
            "Because NGINX does not execute PHP itself",
            "Because MariaDB requires PHP-FPM",
            "Because PHP-FPM creates Docker networks",
            "Because NGINX only works with HTML files"
        ],
        correct: 0,
        explanation: "NGINX does not execute PHP code. PHP-FPM is responsible for processing the PHP used by WordPress. NGINX sends PHP requests to PHP-FPM using FastCGI and returns the generated response to the client."
    },
    {
        question: "What is MariaDB responsible for in the project?",
        answers:
        [
            "Handling HTTPS",
            "Running PHP",
            "Storing WordPress database data",
            "Managing Docker containers"
        ],
        correct: 2,
        explanation: "MariaDB is the database server used by WordPress. It stores data such as users, posts, comments and settings. WordPress manages the website files, while MariaDB manages its database."
    },
    {
        question: "How does WordPress connect to MariaDB?",
        answers:
        [
            "Through the shared Docker network",
            "Through the WordPress volume",
            "Through NGINX",
            "Through the host filesystem"
        ],
        correct: 0,
        explanation: "WordPress and MariaDB are connected to the same Docker network. This allows WordPress to reach MariaDB using its service name and port. Volumes store data, while networks allow containers to communicate."
    },
    {
        question: "Why is a volume used for the MariaDB database?",
        answers:
        [
            "To make MariaDB start faster",
            "To keep database data when the container is recreated",
            "To allow NGINX to execute SQL",
            "To expose MariaDB to the host"
        ],
        correct: 1,
        explanation: "The database must survive when the MariaDB container is removed or recreated. The persistent volume keeps this data outside the lifecycle of the container, allowing a new MariaDB container to use the same database."
    },
    {
        question: "Why does WordPress also have a persistent volume?",
        answers:
        [
            "To store WordPress files persistently",
            "To store the MariaDB database",
            "To store the NGINX certificate",
            "To create the Docker network"
        ],
        correct: 0,
        explanation: "WordPress also contains persistent files, such as uploads, plugins and themes. Its volume keeps these files when the container is recreated. MariaDB uses a separate volume because it stores different data."
    },
    {
        question: "Which TLS versions should the mandatory NGINX accept?",
        answers:
        [
            "TLSv1.0 and TLSv1.1",
            "TLSv1.1 and TLSv1.2",
            "TLSv1.2 and TLSv1.3",
            "All TLS versions"
        ],
        correct: 2,
        explanation: "The mandatory part of Inception requires NGINX to use TLSv1.2 or TLSv1.3. Older versions such as TLSv1.0 and TLSv1.1 must not be enabled. NGINX handles these secure HTTPS connections."
    },
    {
        question: "What is the purpose of Docker Compose in Inception?",
        answers:
        [
            "To replace Dockerfiles",
            "To define and run the project services together",
            "To replace NGINX",
            "To store WordPress data"
        ],
        correct: 1,
        explanation: "Docker Compose defines how the services work together. It configures containers, networks, volumes, ports and secrets. Dockerfiles build each image, while Compose connects and runs the services."
    },
    {
        question: "Why should passwords not be written directly inside a Dockerfile?",
        answers:
        [
            "Dockerfiles cannot contain text",
            "They are sensitive information and should use secrets",
            "MariaDB cannot read Dockerfiles",
            "NGINX automatically deletes passwords"
        ],
        correct: 1,
        explanation: "Passwords are sensitive information and should not be hardcoded into an image. Docker secrets keep credentials separate and make them available only to the containers that need them."
    },
    {
        question: "What happens to persistent data when a container is recreated?",
        answers:
        [
            "It is always deleted",
            "It survives if it is stored in the persistent volume",
            "Docker copies it into the Dockerfile",
            "NGINX stores a backup automatically"
        ],
        correct: 1,
        explanation: "Containers are designed to be replaceable. Data inside the container can disappear when it is removed, but data stored in a persistent volume remains. The new container can mount the same volume and continue using that data."
    }
];

let current = 0;
let score = 0;

function showQuestion()
{
    const question = questions[current];
    const answers = document.getElementById("answers");

    document.getElementById("question").textContent = question.question;
    document.getElementById("explanation").style.display = "none";
    document.getElementById("next").style.display = "none";
    answers.innerHTML = "";

    for (let i = 0; i < question.answers.length; i++)
    {
        const button = document.createElement("button");
        button.textContent = question.answers[i];
        button.className = "answer";
        button.onclick = function()
        {
            const buttons = answers.children;
            for (let j = 0; j < buttons.length; j++)
                buttons[j].disabled = true;
            if (i === question.correct)
            {
                button.className = "answer correct";
                score++;
            }
            else
            {
                button.className = "answer wrong";
                buttons[question.correct].className = "answer correct";
            }
            document.getElementById("explanation").textContent = question.explanation;
            document.getElementById("explanation").style.display = "block";
            document.getElementById("next").style.display = "inline-block";
        };
        answers.appendChild(button);
    }
}

document.getElementById("next").onclick = function()
{
    current++;
    if (current < questions.length)
        showQuestion();
    else
    {
        document.getElementById("quiz").innerHTML = "<h2>Container survived!</h2><p>Score: " + score + "/" + questions.length + "</p>";
    }
};

showQuestion();
