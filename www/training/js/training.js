const choices = document.querySelectorAll(".choice");
const feedback = document.getElementById("feedback");
const continueButton = document.getElementById("continueButton");
const progressBar = document.getElementById("progressBar");
const progressText = document.getElementById("progressText");

let answered = false;

function updateProgress(value) {
    progressBar.style.width = `${value}%`;
    progressText.textContent = `${value}%`;
}

choices.forEach(choice => {
    choice.addEventListener("click", () => {

        if (answered) {
            return;
        }

        answered = true;

        const correct = choice.dataset.correct === "true";

        if (correct) {
            choice.classList.add("correct");

            feedback.textContent =
                "Correct. Verify the sender, context, and destination " +
                "using a trusted channel before taking action.";

            updateProgress(100);

            continueButton.classList.remove("hidden");

        } else {
            choice.classList.add("wrong");

            feedback.textContent =
                "Not quite. Look for the sender, destination, urgency, " +
                "and whether the request makes sense in context.";

            updateProgress(50);

            setTimeout(() => {
                answered = false;
                choice.classList.remove("wrong");
                feedback.textContent =
                    "Try again. Look for the safest first action.";
            }, 1400);
        }
    });
});

continueButton.addEventListener("click", () => {

    /*
     * Keep the campaign tracking ID when moving between
     * King Phisher landing-page paths.
     */
    const params = new URLSearchParams(window.location.search);
    const id = params.get("id");

    const destination = new URL(
        "complete.html",
        window.location.href
    );

    if (id) {
        destination.searchParams.set("id", id);
    }

    window.location.href = destination.href;
});
