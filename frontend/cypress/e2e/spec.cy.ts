describe("View Counter", () => {
  it("Updates the view counter on refresh", () => {
    cy.visit("/");

    cy.wait(3000);

    cy.get('[data-cy="view-count"]').then(($span) => {
      const viewcount1 = parseFloat($span.text());

      cy.reload().then(() => {
        cy.wait(3000).then(() => {
          cy.get('[data-cy="view-count"]').then(($span2) => {
            const viewcount2 = parseFloat($span2.text());

            // Make sure viewcount incremented
            expect(viewcount2).to.eq(viewcount1 + 1);
          });
        });
      });
    });
  });
});
